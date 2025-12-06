locals {
  env           = var.environment
  html_abs_path = "${path.root}/static/${var.html_path}"
}

module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/gcp/appbloc?ref=gcp-appbloc-0.4.2"
  # source         = "../../../blocs/gcp/appbloc"
  namespace      = var.app_namespace
  app_name       = "cloudbloc-webapp-${var.environment}"

  image          = var.app_image
  replicas       = var.app_replicas
  container_port = var.app_port
  domains        = var.domains
  html_path      = local.html_abs_path
  enable_static_html = true

  labels         = {
    env = local.env
    }

  edge_ip_name   = var.edge_ip_name
  cloudarmor_policy = var.security_policy_name
  create_dns_zone = true
}
