locals {
  env = var.environment
}

module "appbloc" {
  source         = "../blocs/appbloc"
  namespace      = var.app_namespace
  edge_ip_name   = var.edge_ip_name
  app_name       = "cloudbloc-webapp-${var.environment}"
  image          = var.app_image
  container_port = var.app_port
  replicas       = var.app_replicas
  service_type   = var.service_type
  labels         = { env = local.env }
  domains        = var.domains
}
