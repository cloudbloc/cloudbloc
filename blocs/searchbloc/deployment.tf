# Deployment: Meilisearch + Nginx + init containers
resource "kubernetes_deployment" "meili" {
  metadata {
    name      = var.app_name
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    replicas = var.replicas

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = local.common_labels
        annotations = {
          "checksum/ui"        = sha256(file("${path.module}/ui/index.html"))
          "checksum/publickey" = sha256(var.public_search_key)
          "checksum/masterkey" = sha256(var.master_key)
        }
      }

      spec {
        # ensure meilisearch (uid/gid 10001) can write the PD
        security_context {
          fs_group = 10001
        }

        # prepare a clean, owned directory per data_rev (sidestep old files)
        init_container {
          name  = "prepare-data"
          image = "busybox:1.36"
          command = [
            "sh",
            "-c"
          ]
          args = [
            "mkdir -p /meili_data/data-v${var.data_rev} && chown -R 10001:10001 /meili_data"
          ]
          volume_mount {
            name       = "data"
            mount_path = "/meili_data"
          }
        }

        # Render UI: inject PUBLIC_SEARCH_KEY into index.html
        init_container {
          name  = "render-ui"
          image = "busybox:1.36"

          command = [
            "sh",
            "-c"
          ]

          args = [
            "sed \"s|__PUBLIC_SEARCH_KEY__|$${PUBLIC_SEARCH_KEY}|g\" /config/index.html > /work/index.html"
          ]
          env {
            name  = "PUBLIC_SEARCH_KEY"
            value = var.public_search_key
          }

          volume_mount {
            name       = "ui-config"
            mount_path = "/config"
            read_only  = true
          }

          volume_mount {
            name       = "ui-work"
            mount_path = "/work"
          }
        }

        # Meilisearch
        container {
          name  = "meilisearch"
          image = var.image

          port {
            container_port = 7700
            name           = "http"
          }

          env {
            name  = "MEILI_ENV"
            value = "production"
          }

          # IMPORTANT: clean subdir tied to data_rev
          env {
            name  = "MEILI_DB_PATH"
            value = "/meili_data/data-v${var.data_rev}"
          }

          env {
            name  = "MEILI_NO_ANALYTICS"
            value = "true"
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.meili.metadata[0].name
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/meili_data"
          }

          resources {
            requests = {
              cpu    = var.resources.requests_cpu
              memory = var.resources.requests_memory
            }

            limits = {
              cpu    = var.resources.limits_cpu
              memory = var.resources.limits_memory
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "http"
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }

        # Nginx UI + reverse proxy
        container {
          name  = "ui"
          image = "nginx:1.27-alpine"

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          port {
            container_port = 80
            name           = "web"
          }

          volume_mount {
            name       = "nginx-conf"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
            read_only  = true
          }

          volume_mount {
            name       = "ui-work"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = "web"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = "web"
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        # Volumes
        volume {
          name = "data"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.data.metadata[0].name
          }
        }

        volume {
          name = "nginx-conf"

          config_map {
            name = kubernetes_config_map.nginx_conf.metadata[0].name
          }
        }

        volume {
          name = "ui-config"

          config_map {
            name = kubernetes_config_map.ui.metadata[0].name
          }
        }

        volume {
          name = "ui-work"

          empty_dir {}
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["autopilot.gke.io/resource-adjustment"],
      metadata[0].annotations["autopilot.gke.io/warden-version"],

      spec[0].template[0].spec[0].toleration,
      spec[0].template[0].spec[0].security_context[0].seccomp_profile,

      # pod template annotations (Autopilot)
      spec[0].template[0].metadata[0].annotations["autopilot.gke.io/resource-adjustment"],
      spec[0].template[0].metadata[0].annotations["autopilot.gke.io/warden-version"],

      # container resources + securityContext (Autopilot tweaks incl. ephemeral-storage)
      spec[0].template[0].spec[0].container[0].resources,
      spec[0].template[0].spec[0].container[1].resources,
      spec[0].template[0].spec[0].container[0].security_context,
      spec[0].template[0].spec[0].container[1].security_context,

      # init containers (if Autopilot touches them)
      spec[0].template[0].spec[0].init_container[0].security_context,
      spec[0].template[0].spec[0].init_container[1].security_context,
    ]
  }

  # ensure PVC exists before scheduling pods
  depends_on = [
    kubernetes_persistent_volume_claim.data
  ]
}

# Service: front port 80 (Nginx), NEG for GCLB
resource "kubernetes_service" "meili" {
  metadata {
    name      = var.app_name
    namespace = var.namespace
    labels    = local.common_labels
    annotations = {
      "cloud.google.com/neg" = "{\"ingress\": true}"
    }
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      name        = "http"
      port        = 80
      target_port = "web"
    }

    type = "ClusterIP"
  }
  lifecycle {
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg-status"],
    ]
  }
}
