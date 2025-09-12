locals {
  dashboards_checksum = sha256(jsonencode(local.effective_dashboards_json))
  effective_dashboards_json = length(var.dashboards_json) > 0 ? var.dashboards_json : {
    "k8s-overview.json" = <<-EOT
    {
      "id": null,
      "uid": "k8s-overview-auto",
      "title": "Kubernetes / Prometheus Overview",
      "timezone": "browser",
      "schemaVersion": 38,
      "version": 1,
      "refresh": "30s",
      "panels": [
        {
          "type": "stat",
          "title": "Targets Up",
          "gridPos": { "h": 6, "w": 6, "x": 0, "y": 0 },
          "options": { "reduceOptions": { "calcs": ["lastNotNull"] } },
          "targets": [{ "expr": "count(up)", "legendFormat": "up" }]
        },
        {
          "type": "timeseries",
          "title": "Up by Job",
          "gridPos": { "h": 10, "w": 12, "x": 6, "y": 0 },
          "targets": [{ "expr": "sum by(job) (up)", "legendFormat": "{{job}}" }]
        },
        {
          "type": "table",
          "title": "Scrape Durations (p95)",
          "gridPos": { "h": 8, "w": 18, "x": 0, "y": 10 },
          "options": { "showHeader": true },
          "targets": [
            {
              "expr": "histogram_quantile(0.95, sum by(job, le) (rate(scrape_duration_seconds_bucket[5m])))",
              "legendFormat": "{{job}}"
            }
          ]
        }
      ]
    }
    EOT
  }
}

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

# Prometheus (lightweight, in-cluster), RBAC for k8s service discovery
resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "prometheus" {
  metadata { name = "${var.app_name}-k8s-discovery" }
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["discovery.k8s.io"]
    resources  = ["endpointslices"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "${var.app_name}-k8s-discovery"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
}

resource "kubernetes_config_map" "prometheus_rules" {
  metadata {
    name      = "prometheus-rules"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  data = {
    "base.yml" = <<-EOT
    groups:
    - name: k8s-basics
      rules:
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[5m]) > 0.1
        for: 5m
        labels: { severity: warning }
        annotations:
          summary: "Pod restarting frequently"
      - alert: HighAPIErrorRate
        expr: rate(apiserver_request_total{code=~"5.."}[5m]) > 1
        for: 10m
        labels: { severity: warning }
        annotations:
          summary: "API server 5xx rate is high"
    EOT
  }
}

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

# Prometheus scrape config
resource "kubernetes_config_map" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 15s

      alerting:
        alertmanagers:
          - static_configs:
              - targets:
                  - "alertmanager.${var.namespace}.svc.cluster.local:9093"

      rule_files:
        - /etc/prometheus/rules/*.yml

      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']

        # Scrape only pods that opt-in via annotations:
        #   prometheus.io/scrape: "true"
        #   prometheus.io/port:   "8080"
        #   prometheus.io/path:   "/metrics" (optional)
        - job_name: 'kubernetes-pods-annotations'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - action: keep
              source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              regex: "true"
            - action: replace
              source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              target_label: __metrics_path__
              regex: (.+)
            - action: replace
              source_labels: [__meta_kubernetes_pod_ip, __meta_kubernetes_pod_annotation_prometheus_io_port]
              target_label: __address__
              regex: (.+);(.+)
              replacement: $1:$2
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - action: replace
              source_labels: [__meta_kubernetes_namespace]
              target_label: namespace
            - action: replace
              source_labels: [__meta_kubernetes_pod_name]
              target_label: pod
    EOT
  }
}



resource "kubernetes_persistent_volume_claim" "prometheus" {
  metadata {
    name      = "prometheus-pvc-${random_id.pvc_suffix.hex}"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.prometheus_storage_size
      }
    }

    storage_class_name = var.prometheus_storage_class
  }

  wait_until_bound = false
}

resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
  }

  spec {
    replicas = 1
    selector { match_labels = { app = "prometheus" } }

    template {
      metadata { labels = merge({ app = "prometheus" }, var.labels) }

      spec {
        service_account_name = kubernetes_service_account.prometheus.metadata[0].name

        security_context {
          run_as_non_root        = true
          run_as_user            = 65534
          run_as_group           = 65534
          fs_group               = 65534
          fs_group_change_policy = "OnRootMismatch"
        }

        init_container {
          name    = "fix-perms"
          image   = "busybox:1.36"
          command = ["sh", "-c", "chown -R 65534:65534 /prometheus && chmod -R g+rwX /prometheus"]
          security_context {
            run_as_user = 0
          }
          volume_mount {
            name       = "prometheus-data"
            mount_path = "/prometheus"
          }
        }

        container {
          name  = "prometheus"
          image = var.prometheus_image

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=${var.prometheus_retention}",
            "--storage.tsdb.retention.size=${var.prometheus_retention_size}",
          ]

          port {
            container_port = 9090
          }

          resources {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "300m", memory = "512Mi" }
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = 9090
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = 9090
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheus/"
          }

          volume_mount {
            name       = "prometheus-data"
            mount_path = "/prometheus"
          }

          volume_mount {
            name       = "prometheus-rules"
            mount_path = "/etc/prometheus/rules"
            read_only  = true
          }
        }

        volume {
          name = "prometheus-config"
          config_map {
            name = kubernetes_config_map.prometheus.metadata[0].name
          }
        }

        volume {
          name = "prometheus-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.prometheus.metadata[0].name
          }
        }

        volume {
          name = "prometheus-rules"
          config_map {
            name = kubernetes_config_map.prometheus_rules.metadata[0].name
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
      spec[0].template[0].spec[0].init_container[0].security_context,
      spec[0].template[0].spec[0].toleration,
    ]
  }

  # wait_for_rollout = false
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels    = var.labels
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = "prometheus"
    }

    port {
      name        = "http"
      port        = 9090
      target_port = 9090
    }
  }
}
