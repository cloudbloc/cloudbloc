locals {
  zone_name = var.create_dns_zone ? google_dns_managed_zone.zone[0].name : data.google_dns_managed_zone.zone[0].name
  base_annotations = {
    "kubernetes.io/ingress.class" = "gce"
    # Allow HTTP listener so GCLB can perform redirect
    "kubernetes.io/ingress.allow-http"            = "true"
    "kubernetes.io/ingress.global-static-ip-name" = var.edge_ip_name
    "networking.gke.io/managed-certificates"      = kubernetes_manifest.managed_cert.manifest.metadata.name
    "networking.gke.io/v1beta1.FrontendConfig"    = kubernetes_manifest.frontend_config.manifest.metadata.name
  }

  armor_annotation = var.cloudarmor_policy == null ? {} : {
    "gcp.cloud.google.com/security-policy" = var.cloudarmor_policy
  }
}

# FrontendConfig to 301 redirect HTTP -> HTTPS
resource "kubernetes_manifest" "frontend_config" {
  manifest = {
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = "${var.app_name}-frontend"
      namespace = kubernetes_namespace.namespace.metadata[0].name
    }
    spec = {
      redirectToHttps = {
        enabled = true
      }
    }
  }
}

# Reserve a global static IP
resource "google_compute_global_address" "app_edge_ip" {
  name = var.edge_ip_name

}

data "google_dns_managed_zone" "zone" {
  count = var.create_dns_zone ? 0 : 1
  name  = var.dns_zone_name
}

# DNS managed zone based on the first domain
resource "google_dns_managed_zone" "zone" {
  count = var.create_dns_zone ? 1 : 0

  name        = replace(var.domains[0], ".", "-") # e.g. "cloudbloc-io"
  dns_name    = "${var.domains[0]}."              # e.g. "cloudbloc.io."
  description = "Zone for ${var.domains[0]}"
}

# A records for every domain in var.domains
resource "google_dns_record_set" "a_records" {
  for_each     = toset(var.domains)
  name         = "${each.value}." # e.g. "cloudbloc.io.", "www.cloudbloc.io."
  type         = "A"
  ttl          = 300
  managed_zone = local.zone_name
  rrdatas      = [google_compute_global_address.app_edge_ip.address]
}

resource "kubernetes_ingress_v1" "web" {
  metadata {
    name      = "${var.app_name}-ingress"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    annotations = merge(
      local.base_annotations,
      local.armor_annotation,
      var.extra_ingress_annotations
    )
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
