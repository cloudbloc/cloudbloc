# Managed cert gets both Obs + Search domains when enabled
locals {
  # full host list (obs + searchbloc if enabled)
  all_domains = sort(distinct(
    var.enable_searchbloc ? concat(var.domains, var.searchbloc_domains) : var.domains
  ))

  # change name when domains change (forces a *new* cert instead of in-place update)
  cert_name = "${var.app_name}-cert-${substr(sha1(join(",", local.all_domains)), 0, 8)}"
}

resource "kubernetes_manifest" "managed_cert" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = local.cert_name
      namespace = kubernetes_namespace.namespace.metadata[0].name
    }
    spec = { domains = local.all_domains }
  }
}
