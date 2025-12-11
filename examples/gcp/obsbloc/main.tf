module "obsbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/gcp/obsbloc?ref=gcp-obsbloc-v0.4.3"

  # source       = "../../../blocs/gcp/obsbloc"
  namespace    = var.namespace
  app_name     = var.app_name
  edge_ip_name = var.edge_ip_name
  domains      = var.domains

  # searchbloc
  enable_searchbloc  = true
  searchbloc_domains = var.searchbloc_domains
  searchbloc_service = "searchbloc"

  # Existing Cloud DNS managed zone NAME (e.g., google_dns_managed_zone.cloudbloc.name)
  zone_name         = var.zone_name
  cloudarmor_policy = var.security_policy_name
  dashboards_json = {
    "k8s-overview.json"         = file("${path.module}/dashboards/k8s-overview.json")
    "prometheus-internals.json" = file("${path.module}/dashboards/prometheus-internals.json")
  }
}
