locals {
  # still useful for rolling pods on env change
  env_checksum = sha256(jsonencode(var.env))
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


