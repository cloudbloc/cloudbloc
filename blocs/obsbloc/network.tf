# Global static IP + ManagedCertificate + Ingress

locals {
  base_annotations = {
    "kubernetes.io/ingress.class"                 = "gce"
    "kubernetes.io/ingress.allow-http"            = "true" # allow listener so it can redirect
    "kubernetes.io/ingress.global-static-ip-name" = var.edge_ip_name
    "networking.gke.io/managed-certificates"      = kubernetes_manifest.managed_cert.manifest.metadata.name
    "networking.gke.io/v1beta1.FrontendConfig"    = kubernetes_manifest.obsbloc_frontendconfig.manifest.metadata.name
  }

  armor_annotation = var.cloudarmor_policy == null ? {} : {
    "gcp.cloud.google.com/security-policy" = var.cloudarmor_policy
  }
}

# Reserve a global static IP for the Ingress
resource "google_compute_global_address" "edge_ip" {
  name = var.edge_ip_name
}

# 1) FrontendConfig (GKE) to enforce HTTPS redirect
resource "kubernetes_manifest" "obsbloc_frontendconfig" {
  manifest = {
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = "obsbloc-frontendconfig"
      namespace = kubernetes_namespace.namespace.metadata[0].name
    }
    spec = {
      redirectToHttps = {
        enabled          = true
        responseCodeName = "MOVED_PERMANENTLY_DEFAULT" # 301
      }
    }
  }
}

# GCE Ingress pointing to Grafana service, using the static IP + cert
resource "kubernetes_ingress_v1" "grafana" {
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
        name = kubernetes_service.grafana.metadata[0].name
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
                name = kubernetes_service.grafana.metadata[0].name
                port { number = 80 }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.managed_cert]
}

# DNS records ONLY (use existing managed zone)
resource "google_dns_record_set" "a_records" {
  for_each     = toset(var.domains)
  name         = "${each.value}." # e.g. "obsbloc.cloudbloc.io."
  type         = "A"
  ttl          = 300
  managed_zone = var.zone_name # existing zone NAME
  rrdatas      = [google_compute_global_address.edge_ip.address]
}
