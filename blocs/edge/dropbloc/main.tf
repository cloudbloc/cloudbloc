locals {
  # If user doesn’t specify a canonical host, fall back to domain
  nextcloud_canonical_host = (
    var.nextcloud_canonical_host != "" ?
    var.nextcloud_canonical_host :
    var.nextcloud_hostname
  )

  nextcloud_canonical_protocol = var.nextcloud_canonical_protocol
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

# StorageClass for local hostPath PVs (no provisioner)
resource "kubernetes_storage_class_v1" "nextcloud_local" {
  metadata {
    name = var.storage_class_name
  }

  storage_provisioner = "kubernetes.io/no-provisioner"
  volume_binding_mode = "WaitForFirstConsumer"
}

# Static PV backed by hostPath on local
resource "kubernetes_persistent_volume_v1" "nextcloud_data" {
  metadata {
    name = "nextcloud-data-pv"
  }

  spec {
    capacity = {
      storage = var.data_size
    }

    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = var.storage_class_name

    persistent_volume_source {
      host_path {
        path = var.data_host_path
        type = "DirectoryOrCreate"
      }
    }
  }

  depends_on = [kubernetes_storage_class_v1.nextcloud_local]
}

# PVC in the same namespace, bound to the PV above
resource "kubernetes_persistent_volume_claim_v1" "nextcloud_data" {
  metadata {
    name      = "nextcloud-data-pvc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  wait_until_bound = true

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.data_size
      }
    }

    storage_class_name = var.storage_class_name
    volume_name        = kubernetes_persistent_volume_v1.nextcloud_data.metadata[0].name
  }
}

# Nextcloud Helm release
resource "helm_release" "nextcloud" {
  name      = "nextcloud"
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  repository = "https://nextcloud.github.io/helm/"
  chart      = "nextcloud"
  version    = var.chart_version

  timeout = 600
  wait    = false

  values = [
    yamlencode({
      service = {
        type       = "NodePort"
        port       = 80
        targetPort = 80
        nodePort   = var.service_node_port
      }

      ingress = {
        enabled = false
        hosts   = []
      }

      nextcloud = {
        host = "${var.node_ip}:${var.service_node_port}"

        trustedDomains = [
          var.node_ip,
          "${var.node_ip}:${var.service_node_port}",
          local.nextcloud_canonical_host,
        ]

        extraEnv = [
          {
            name  = "OVERWRITEHOST"
            value = local.nextcloud_canonical_host

          },
          {
            name  = "OVERWRITEPROTOCOL"
            value = local.nextcloud_canonical_protocol

          },
          {
            name  = "PHP_MEMORY_LIMIT"
            value = var.php_memory_limit
          },
          {
            name  = "PHP_UPLOAD_LIMIT"
            value = var.php_upload_limit
          },
          {
            name  = "PHP_MAX_EXECUTION_TIME"
            value = var.php_max_execution_time
          },
        ]

        phpConfigs = {
          "zz-custom.ini" = <<-EOT
memory_limit = ${var.php_memory_limit}
upload_max_filesize = ${var.php_upload_limit}
post_max_size = ${var.php_upload_limit}
max_execution_time = ${var.php_max_execution_time}
max_input_time = ${var.php_max_execution_time}
EOT
        }

        username = var.admin_username
        password = var.admin_password
      }

      podSecurityContext = {
        fsGroup             = 33
        fsGroupChangePolicy = "OnRootMismatch"
      }

      securityContext = {
        runAsUser              = 33
        runAsGroup             = 33
        runAsNonRoot           = true
        readOnlyRootFilesystem = false
      }

      internalDatabase = {
        enabled = true
      }

      persistence = {
        enabled = true

        nextcloudData = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.nextcloud_data.metadata[0].name
        }
      }

      livenessProbe = {
        enabled = false
      }
      readinessProbe = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_persistent_volume_claim_v1.nextcloud_data,
  ]
}

########################
# Cloudflared (Tunnel) #
########################

# Secret: cloudflared credentials.json
resource "kubernetes_secret" "cloudflared_credentials" {
  count = var.enable_cloudflared ? 1 : 0

  metadata {
    name      = "cloudflared-credentials"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "credentials.json" = file(var.cloudflared_credentials_file)
  }

  type = "Opaque"
}

resource "kubernetes_config_map" "cloudflared_config" {
  count = var.enable_cloudflared ? 1 : 0

  metadata {
    name      = "cloudflared-config"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  data = {
    "config.yaml" = <<-EOT
tunnel: ${var.cloudflared_tunnel_id}
credentials-file: /etc/cloudflared/credentials/credentials.json

ingress:
  - hostname: ${var.nextcloud_hostname}
    service: http://nextcloud.${var.namespace}.svc.cluster.local:80
  - service: http_status:404
EOT
  }
}


# Deployment: cloudflared
resource "kubernetes_deployment" "cloudflared" {
  count = var.enable_cloudflared ? 1 : 0

  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      app = "cloudflared"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "cloudflared"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }

      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"

          args = [
            "tunnel",
            "--config",
            "/etc/cloudflared/config/config.yaml",
            "run",
          ]

          volume_mount {
            name       = "config"
            mount_path = "/etc/cloudflared/config"
          }

          volume_mount {
            name       = "credentials"
            mount_path = "/etc/cloudflared/credentials"
            read_only  = true
          }
        }

        volume {
          name = "config"

          config_map {
            # safe because count = 1 when enabled, 0 when disabled
            name = kubernetes_config_map.cloudflared_config[0].metadata[0].name

            items {
              key  = "config.yaml"
              path = "config.yaml"
            }
          }
        }

        volume {
          name = "credentials"

          secret {
            secret_name = kubernetes_secret.cloudflared_credentials[0].metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_config_map.cloudflared_config,
    kubernetes_secret.cloudflared_credentials,
  ]
}
