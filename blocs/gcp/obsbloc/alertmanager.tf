resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  data = {
    "alertmanager.yml" = <<-EOT
    route:
      receiver: "default"
    receivers:
      - name: "default"
        # replace with a real receiver later; starts “silent” for MVP
    EOT
  }
}

resource "kubernetes_deployment" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "alertmanager" } }

    template {
      metadata { labels = merge({ app = "alertmanager" }, var.labels) }
      spec {
        container {
          name  = "alertmanager"
          image = "quay.io/prometheus/alertmanager:v0.27.0"
          args  = ["--config.file=/etc/alertmanager/alertmanager.yml"]
          port {
            container_port = 9093
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "100Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "cfg"
            mount_path = "/etc/alertmanager/"
            read_only  = true
          }
        }

        volume {
          name = "cfg"
          config_map { name = kubernetes_config_map.alertmanager_config.metadata[0].name }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # Autopilot mutates these:
      metadata[0].annotations["autopilot.gke.io/resource-adjustment"],
      metadata[0].annotations["autopilot.gke.io/warden-version"],

      # Provider/server round-trip noise:
      spec[0].template[0].spec[0].toleration,             # Autopilot injects arch toleration
      spec[0].template[0].spec[0].container[0].resources, # adds ephemeral-storage
      spec[0].template[0].spec[0].security_context,
      spec[0].template[0].spec[0].container[0].security_context,
      spec[0].template[0].spec[0].init_container[0].security_context,
    ]
  }
}

resource "kubernetes_service" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "alertmanager"
    }

    port {
      name        = "http"
      port        = 9093
      target_port = 9093
    }
  }
}
