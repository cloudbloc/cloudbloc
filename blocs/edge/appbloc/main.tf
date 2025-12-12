locals {
  # still useful for rolling pods on env change
  env_checksum = sha256(jsonencode(var.env))

  # If worker_env is empty, inherit env from web container
  worker_env = length(var.worker_env) > 0 ? var.worker_env : var.env
}

resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_config_map_v1" "web_html" {
  count = var.enable_static_html ? 1 : 0

  metadata {
    name      = "web-html"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  data = {
    "index.html" = file(var.html_path)
  }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    labels    = merge({ app = var.app_name }, var.labels)
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = merge({ app = var.app_name }, var.labels)
        annotations = {
          "cloudbloc.io/env-checksum" = local.env_checksum
        }
      }

      spec {
        container {
          name  = "web"
          image = var.image

          dynamic "env" {
            for_each = var.env
            content {
              name  = env.key
              value = env.value
            }
          }

          port {
            container_port = var.container_port
          }

          # small default resources – tweak per app
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          # serve our HTML from ConfigMap if enabled
          dynamic "volume_mount" {
            for_each = var.enable_static_html ? [1] : []
            content {
              name       = "html"
              mount_path = "/usr/share/nginx/html"
              read_only  = true
            }
          }
        }

        dynamic "image_pull_secrets" {
          for_each = var.worker_image_pull_secret != null ? [1] : []
          content {
            name = var.worker_image_pull_secret
          }
        }

        dynamic "volume" {
          for_each = var.enable_static_html ? [kubernetes_config_map_v1.web_html[0].metadata[0].name] : []
          content {
            name = "html"

            config_map {
              name = volume.value
            }
          }
        }
      }
    }
  }
}

########################################
# NEW: Optional YouTube automation worker (CronJob)
########################################

resource "kubernetes_cron_job_v1" "worker" {
  count = var.enable_worker ? 1 : 0

  metadata {
    name      = "${var.app_name}-worker"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    labels    = merge({ app = "${var.app_name}-worker" }, var.labels)
  }

  spec {
    schedule                      = var.worker_schedule
    concurrency_policy            = var.worker_concurrency_policy
    successful_jobs_history_limit = var.worker_successful_jobs_history_limit
    failed_jobs_history_limit     = var.worker_failed_jobs_history_limit

    job_template {
      metadata {
        labels = merge({ app = "${var.app_name}-worker" }, var.labels)
      }

      spec {
        backoff_limit = var.worker_backoff_limit

        template {
          metadata {
            labels = merge({ app = "${var.app_name}-worker" }, var.labels)
          }

          spec {
            container {
              name = "worker"
              # If worker_image is "", reuse the main image
              image = var.worker_image != "" ? var.worker_image : var.image

              dynamic "env" {
                for_each = local.worker_env
                content {
                  name  = env.key
                  value = env.value
                }
              }

              dynamic "env" {
                for_each = var.worker_env_from_secret
                content {
                  name = env.key
                  value_from {
                    secret_key_ref {
                      name = env.value
                      key  = env.key
                    }
                  }
                }
              }

              # Optional hostPath mounts for /input and /output
              dynamic "volume_mount" {
                for_each = var.worker_input_host_path != null ? [1] : []
                content {
                  name       = "worker-input"
                  mount_path = "/input"
                  read_only  = false
                }
              }

              dynamic "volume_mount" {
                for_each = var.worker_output_host_path != null ? [1] : []
                content {
                  name       = "worker-output"
                  mount_path = "/output"
                  read_only  = false
                }
              }

              # command/args are attributes, not blocks
              command = var.worker_command
              args    = var.worker_args

              resources {
                requests = {
                  cpu    = var.worker_requests_cpu
                  memory = var.worker_requests_memory
                }
                limits = {
                  cpu    = var.worker_limits_cpu
                  memory = var.worker_limits_memory
                }
              }
            }


            restart_policy = var.worker_restart_policy

            dynamic "image_pull_secrets" {
              for_each = var.worker_image_pull_secret != null ? [1] : []
              content {
                name = var.worker_image_pull_secret
              }
            }

            # Optional hostPath volumes backing /input and /output
            dynamic "volume" {
              for_each = var.worker_input_host_path != null ? [1] : []
              content {
                name = "worker-input"

                host_path {
                  path = var.worker_input_host_path
                  type = "DirectoryOrCreate"
                }
              }
            }

            dynamic "volume" {
              for_each = var.worker_output_host_path != null ? [1] : []
              content {
                name = "worker-output"

                host_path {
                  path = var.worker_output_host_path
                  type = "DirectoryOrCreate"
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "web" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
    labels    = var.labels
  }

  spec {
    # homelab: expose via NodePort to LAN or Cloudflare tunnel
    type = "NodePort"

    selector = {
      app = var.app_name
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
      node_port   = var.node_port
    }
  }
}

########################################
# Optional Cloudflare tunnel (in-cluster)
########################################

# Secret with tunnel credentials
resource "kubernetes_secret_v1" "cloudflared_credentials" {
  count = var.enable_cloudflared ? 1 : 0

  metadata {
    name      = "cloudflared-credentials"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  data = {
    # Cloudflare expects <tunnel_id>.json
    "${var.cloudflared_tunnel_id}.json" = var.cloudflared_credentials_json
  }

  type = "Opaque"
}

# ConfigMap with config.yaml
resource "kubernetes_config_map_v1" "cloudflared_config" {
  count = var.enable_cloudflared ? 1 : 0

  metadata {
    name      = "cloudflared-config"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
  }

  data = {
    "config.yaml" = <<-EOF
    tunnel: ${var.cloudflared_tunnel_id}
    credentials-file: /etc/cloudflared/credentials/${var.cloudflared_tunnel_id}.json

    ingress:
      - hostname: ${var.cloudflared_hostname}
        service: http://${kubernetes_service_v1.web.metadata[0].name}.${var.namespace}.svc.cluster.local:80

      - hostname: www.${var.cloudflared_hostname}
        service: http://${kubernetes_service_v1.web.metadata[0].name}.${var.namespace}.svc.cluster.local:80

      - service: http_status:404
    EOF
  }
}

# cloudflared Deployment
resource "kubernetes_deployment_v1" "cloudflared" {
  count = var.enable_cloudflared ? 1 : 0

  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.namespace.metadata[0].name
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
            name = kubernetes_config_map_v1.cloudflared_config[0].metadata[0].name

            items {
              key  = "config.yaml"
              path = "config.yaml"
            }
          }
        }

        volume {
          name = "credentials"

          secret {
            secret_name = kubernetes_secret_v1.cloudflared_credentials[0].metadata[0].name
          }
        }
      }
    }
  }
}
