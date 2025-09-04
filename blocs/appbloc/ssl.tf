resource "kubernetes_manifest" "managed_cert" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "${var.app_name}-cert"
      namespace = kubernetes_namespace.namespace.metadata[0].name
    }
    spec = {
      domains = var.domains
    }
  }
}