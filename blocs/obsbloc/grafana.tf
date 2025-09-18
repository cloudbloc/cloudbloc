resource "random_id" "pvc_suffix" {
  byte_length = 2
  keepers     = { data_rev = var.data_rev } # changes when data_rev changes
}

resource "kubernetes_namespace" "namespace" {
  metadata { name = var.namespace }
}

# Grafana (anonymous, read-only)
resource "kubernetes_config_map" "grafana_ini" {
  metadata {
    name      = "grafana-ini"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = {
    "grafana.ini" = <<-EOT
      [auth.anonymous]
      enabled = true
      org_role = Viewer
    EOT
  }
}

# Pre-provision Prometheus datasource
resource "kubernetes_config_map" "grafana_datasource" {
  metadata {
    name      = "grafana-datasource"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = {
    "prometheus-datasource.yml" = <<-EOT
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          access: proxy
          url: http://prometheus.${var.namespace}.svc.cluster.local:9090
          isDefault: true
    EOT
  }
}

# Provisioning: tell Grafana to auto-load dashboards from a folder
resource "kubernetes_config_map" "grafana_dashboard_provider" {
  metadata {
    name      = "grafana-dashboard-provider"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = {
    "provider.yaml" = <<-EOT
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        allowUiUpdates: false
        updateIntervalSeconds: 30
        options:
          path: /var/lib/grafana/dashboards
          foldersFromFilesStructure: false
    EOT
  }
}

# A tiny default dashboard so first load isn't empty
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = local.effective_dashboards_json
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
  }

  spec {
    replicas = var.replicas

    selector { match_labels = { app = var.app_name } }

    template {
      metadata {
        labels = merge({ app = var.app_name }, var.labels)
        annotations = {
          "cloudbloc.io/dashboards-checksum" = local.dashboards_checksum
        }
      }

      spec {
        container {
          name  = "grafana"
          image = var.grafana_image

          # set server settings via env (works behind GCLB/Ingress)
          env {
            name  = "GF_SERVER_DOMAIN"
            value = var.domains[0] # e.g. "obsbloc.cloudbloc.io"
          }
          env {
            name  = "GF_SERVER_ROOT_URL"
            value = "https://${var.domains[0]}/"
          }
          env {
            name  = "GF_SERVER_SERVE_FROM_SUB_PATH"
            value = "false"
          }
          # Keep anonymous viewing controlled by grafana.ini you already mount
          # (no need to duplicate GF_AUTH_* envs unless you prefer env-only config)

          port {
            container_port = 3000
          }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "300m", memory = "256Mi" }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          # grafana.ini (anonymous viewer)
          volume_mount {
            name       = "grafana-ini"
            mount_path = "/etc/grafana/grafana.ini"
            sub_path   = "grafana.ini"
            read_only  = true
          }

          # Prometheus datasource provisioning
          volume_mount {
            name       = "grafana-datasource"
            mount_path = "/etc/grafana/provisioning/datasources/prometheus.yml"
            sub_path   = "prometheus-datasource.yml"
            read_only  = true
          }

          # Dashboard provider (where to load dashboards from)
          volume_mount {
            name       = "grafana-dashboard-provider"
            mount_path = "/etc/grafana/provisioning/dashboards/provider.yaml"
            sub_path   = "provider.yaml"
            read_only  = true
          }

          # Default dashboard JSON
          volume_mount {
            name       = "grafana-dashboards"
            mount_path = "/var/lib/grafana/dashboards"
            read_only  = true
          }
        }

        volume {
          name = "grafana-ini"
          config_map { name = kubernetes_config_map.grafana_ini.metadata[0].name }
        }

        volume {
          name = "grafana-datasource"
          config_map { name = kubernetes_config_map.grafana_datasource.metadata[0].name }
        }

        volume {
          name = "grafana-dashboard-provider"
          config_map { name = kubernetes_config_map.grafana_dashboard_provider.metadata[0].name }
        }

        volume {
          name = "grafana-dashboards"
          config_map { name = kubernetes_config_map.grafana_dashboards.metadata[0].name }
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

resource "kubernetes_service" "grafana" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    annotations = {
      "cloud.google.com/neg" = jsonencode({ ingress = true })
    }
    labels = var.labels
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = var.app_name
    }
    port {
      name        = "http"
      port        = 80
      target_port = 3000
      protocol    = "TCP"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["cloud.google.com/neg-status"],
    ]
  }
}
