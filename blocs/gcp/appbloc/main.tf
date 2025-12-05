locals {
  env_checksum = sha256(jsonencode(var.env))
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_config_map" "web_html" {
  count = var.enable_static_html ? 1 : 0
  metadata {
    name      = "web-html"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  data = {
    "index.html" = file(var.html_path)
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
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

          # tiny requests to keep Autopilot costs low
          resources {
            requests = {
              cpu    = "100m",
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m",
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

          # serve our HTML
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
          for_each = var.enable_static_html ? [kubernetes_config_map.web_html[0].metadata[0].name] : []
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

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["autopilot.gke.io/resource-adjustment"],
      metadata[0].annotations["autopilot.gke.io/warden-version"],
      spec[0].template[0].spec[0].container[0].resources,
      spec[0].template[0].spec[0].security_context,
      spec[0].template[0].spec[0].container[0].security_context,
      spec[0].template[0].spec[0].toleration,
    ]
  }
}

resource "kubernetes_service" "web" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    annotations = {
      "cloud.google.com/neg" = jsonencode({ ingress = true })
    }
    labels = var.labels
  }

  spec {
    type     = "ClusterIP"
    selector = { app = var.app_name }
    port {
      name        = "http"
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg-status"],
    ]
  }
}
