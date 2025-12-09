resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_persistent_volume_v1" "nextcloud_data" {
  metadata {
    name = "nextcloud-data-pv"
  }

  spec {
    capacity = {
      storage = "800Gi"
    }

    access_modes = ["ReadWriteOnce"]

    persistent_volume_reclaim_policy = "Retain"
    storage_class_name               = "nextcloud-local-storage"

    persistent_volume_source {
      host_path {
        path = "/mnt/dropbloc/nextcloud-data"
        type = "DirectoryOrCreate"
      }
    }
  }
}


resource "kubernetes_persistent_volume_claim_v1" "nextcloud_data" {
  metadata {
    name      = "nextcloud-data-pvc"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  # So Terraform doesn't spin forever if binding is a bit slow
  wait_until_bound = true

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "800Gi"
      }
    }

    storage_class_name = "nextcloud-local-storage"
    volume_name        = kubernetes_persistent_volume_v1.nextcloud_data.metadata[0].name
  }
}

resource "helm_release" "nextcloud" {
  name      = "nextcloud"
  namespace = kubernetes_namespace_v1.this.metadata[0].name

  repository = "https://nextcloud.github.io/helm/"
  chart      = "nextcloud"
  version    = var.chart_version

  # Make Terraform/Helm less strict for homelab
  timeout = 600 # 10 minutes, just in case
  wait    = false

  values = [
    yamlencode({
      service = {
        type       = "NodePort"
        port       = 80
        targetPort = 80
        nodePort   = 30080
      }

      # You currently have no ingress controller; keep this off for now
      ingress = {
        enabled = false
        hosts   = []
      }

      nextcloud = {
        host = "10.0.0.187:30080"

        trustedDomains = [
          "10.0.0.187",
          "10.0.0.187:30080"
        ]

        extraEnv = [
          {
            name  = "OVERWRITEHOST"
            value = "10.0.0.187:30080"
          },
          {
            name  = "OVERWRITEPROTOCOL"
            value = "http"
          },
          {
            name  = "PHP_MEMORY_LIMIT"
            value = "2048M"
          },
          {
            name  = "PHP_UPLOAD_LIMIT"
            value = "16G"
          },
          {
            name  = "PHP_MAX_EXECUTION_TIME"
            value = "3600"
          },
        ]

        phpConfigs = {
          "zz-custom.ini" = <<-EOT
memory_limit = 2048M
upload_max_filesize = 16G
post_max_size = 16G
max_execution_time = 3600
max_input_time = 3600
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

      # Use the internal DB (sqlite/mariadb via chart) – fine for homelab
      internalDatabase = {
        enabled = true
      }

      # Persistence:
      # - main app/config (/var/www/html) -> stays on internal disk (default storage)
      # - data directory (/var/www/html/data) -> goes to SSD via our PVC
      persistence = {
        # Keep this true so the chart still uses a PVC for /var/www/html
        # but let it use the default StorageClass (no existingClaim here).
        enabled = true

        # Put ONLY the big user data (photos/videos/files) on the SSD
        nextcloudData = {
          enabled       = true
          existingClaim = kubernetes_persistent_volume_claim_v1.nextcloud_data.metadata[0].name
        }
      }

      # Relax probes so it doesn't flap during init on homelab
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

# Secret: cloudflared credentials.json
resource "kubernetes_secret" "cloudflared_credentials" {
  metadata {
    name      = "cloudflared-credentials"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  # Pass the raw file contents; provider handles encoding
  data = {
    "credentials.json" = file(var.cloudflared_credentials_file)
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace_v1.this
  ]
}

# ConfigMap: cloudflared config.yaml
resource "kubernetes_config_map" "cloudflared_config" {
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

  depends_on = [
    kubernetes_namespace_v1.this
  ]
}

# Deployment: cloudflared
resource "kubernetes_deployment" "cloudflared" {
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
            name = kubernetes_config_map.cloudflared_config.metadata[0].name

            items {
              key  = "config.yaml"
              path = "config.yaml"
            }
          }
        }

        volume {
          name = "credentials"

          secret {
            secret_name = kubernetes_secret.cloudflared_credentials.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_config_map.cloudflared_config,
    kubernetes_secret.cloudflared_credentials
  ]
}
