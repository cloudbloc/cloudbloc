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
