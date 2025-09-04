resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_config_map" "web_html" {
  metadata {
    name      = "web-html"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  data = {
    "index.html" = <<-HTML
      <!doctype html>
      <html><head><title>Cloudbloc</title></head>
      <body style="font-family:sans-serif">
        <h1>Cloudbloc — it works 🎉</h1>
      </body></html>
    HTML
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
      }

      spec {
        container {
          name  = "web"
          image = var.image

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
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }
        }

        volume {
          name = "html"
          config_map {
            name = kubernetes_config_map.web_html.metadata[0].name
          }
        }
      }
    }
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
}

resource "kubernetes_ingress_v1" "web" {
  metadata {
    name      = "${var.app_name}-ingress"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.allow-http"            = "false"
      "kubernetes.io/ingress.global-static-ip-name" = var.edge_ip_name
      "networking.gke.io/managed-certificates"      = kubernetes_manifest.managed_cert.manifest.metadata.name
    }
  }

  spec {
    default_backend {
      service {
        name = kubernetes_service.web.metadata[0].name
        port {
          number = 80
        }
      }
    }

    dynamic "rule" {
      for_each = var.domains
      content {
        host = rule.value
        http {
          path {
            path      = "/*"
            path_type = "ImplementationSpecific"
            backend {
              service {
                name = kubernetes_service.web.metadata[0].name
                port {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.managed_cert]
}
