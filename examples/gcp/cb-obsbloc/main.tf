module "obsbloc" {
  source       = "../../../blocs/obsbloc"
  namespace    = var.namespace
  app_name     = var.app_name
  edge_ip_name = var.edge_ip_name
  domains      = var.domains

  # Existing Cloud DNS managed zone NAME (e.g., google_dns_managed_zone.cloudbloc.name)
  zone_name = var.zone_name
}
