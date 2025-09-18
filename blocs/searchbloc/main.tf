resource "random_id" "pvc_suffix" {
  byte_length = 2
  keepers = {
    data_rev = var.data_rev
  }
}

locals {
  backup_bucket_uri = "gs://${var.backup_bucket_name}"
  common_labels = merge(
    tomap({
      app = var.app_name
    }),
    var.labels
  )
}

# Nginx reverse proxy: / -> static UI, /api/* -> Meilisearch
resource "kubernetes_config_map" "nginx_conf" {
  metadata {
    name      = "${var.app_name}-nginx-conf"
    namespace = var.namespace
    labels    = local.common_labels
  }

  data = {
    "nginx.conf" = <<-NGINX
      events {}
      http {
        server {
          listen 80;

          # static UI
          location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri /index.html;
          }

          # health for LB
          location = /healthz {
            return 200 'ok';
            add_header Content-Type text/plain;
          }

          # API proxy to Meili on localhost:7700
          location /api/ {
            proxy_pass http://127.0.0.1:7700/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Authorization     $http_authorization;
          }
        }
      }
    NGINX
  }
}

# Minimal UI (index.html) — initContainer injects PUBLIC_SEARCH_KEY
resource "kubernetes_config_map" "ui" {
  metadata {
    name      = "${var.app_name}-ui"
    namespace = var.namespace
    labels    = local.common_labels
  }

  data = {
    "index.html" = file("${path.module}/ui/index.html")
  }
}

# Storage (PVC rotates with data_rev) & Secret
resource "kubernetes_persistent_volume_claim" "data" {
  metadata {
    # example: searchbloc-data-r2ab3c
    name      = "${var.app_name}-data-r${var.data_rev}${random_id.pvc_suffix.hex}"
    namespace = var.namespace
    labels    = local.common_labels
  }

  # avoid WFFC stall; the pod will trigger binding
  wait_until_bound = false

  lifecycle {
    create_before_destroy = true
  }

  spec {
    access_modes = [
      "ReadWriteOnce"
    ]

    resources {
      requests = {
        storage = var.storage_size
      }
    }

    storage_class_name = var.storage_class_name
  }
}

resource "kubernetes_secret" "meili" {
  metadata {
    name      = "${var.app_name}-secrets"
    namespace = var.namespace
    labels    = local.common_labels
  }

  type = "Opaque"

  data = {
    MEILI_MASTER_KEY = base64encode(var.master_key)
  }
}

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

      # pod-level
      spec[0].template[0].spec[0].toleration,
      spec[0].template[0].spec[0].security_context[0].seccomp_profile,

      # containers
      spec[0].template[0].spec[0].container[0].resources,
      spec[0].template[0].spec[0].container[0].security_context, # meilisearch
      spec[0].template[0].spec[0].container[1].security_context, # ui

      # init containers
      spec[0].template[0].spec[0].init_container[0].security_context, # prepare-data
      spec[0].template[0].spec[0].init_container[1].security_context, # render-ui
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

resource "google_storage_bucket" "backups" {
  project                     = var.project_id
  name                        = var.backup_bucket_name
  location                    = var.backup_bucket_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning { enabled = true } # protect against accidental overwrite

  lifecycle_rule {
    condition { age = 30 } # keep 30 days of backups
    action { type = "Delete" }
  }

  retention_policy {
    retention_period = 604800 # 7 days (seconds)
  }
}

resource "google_service_account" "backups" {
  project      = var.project_id
  account_id   = "backups-writer"
  display_name = "SearchBloc backups writer"
}

resource "google_storage_bucket_iam_member" "writer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.backups.email}"
}

resource "google_storage_bucket_iam_member" "viewer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.backups.email}"
}

resource "google_storage_bucket_iam_member" "admin" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backups.email}"
}

resource "kubernetes_service_account" "backup" {
  metadata {
    name      = "${var.app_name}-backup"
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.backups.email
    }
    labels = local.common_labels
  }
}

# Allow KSA to impersonate GCP SA
resource "google_service_account_iam_member" "wi_bind" {
  service_account_id = google_service_account.backups.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${kubernetes_service_account.backup.metadata[0].name}]"
}

# CronJob (no secrets, WI auth)
resource "kubernetes_cron_job_v1" "meili_backup" {
  metadata {
    name      = "${var.app_name}-backup"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    schedule                      = "0 3 * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = local.common_labels
      }
      spec {
        backoff_limit = 2
        template {
          metadata {
            labels = local.common_labels
          }
          spec {
            service_account_name = kubernetes_service_account.backup.metadata[0].name
            restart_policy       = "OnFailure"

            # Make sure we can read Meili’s PVC (matches your Deployment)
            security_context { fs_group = 10001 }

            container {
              name    = "backup"
              image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:latest"
              command = ["bash", "-lc"]
              args = [
                "gsutil -m rsync -r /meili_data ${local.backup_bucket_uri}/meili/$(date +%F)/"
              ]

              resources {
                requests = {
                  cpu    = "100m"
                  memory = "256Mi"
                }
                limits = {
                  cpu    = "500m"
                  memory = "1Gi"
                }
              }

              volume_mount {
                name       = "data"
                mount_path = "/meili_data"
              }
            }

            volume {
              name = "data"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.data.metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}
