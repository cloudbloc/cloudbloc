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
