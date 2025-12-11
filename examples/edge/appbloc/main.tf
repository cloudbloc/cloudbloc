locals {
  env           = var.environment
  html_abs_path = "${path.root}/static/${var.html_path}"
}

module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/appbloc?ref=edge-appbloc-v0.1.0"
  # source = "../../../blocs/edge/appbloc"

  namespace      = var.app_namespace
  app_name       = "cloudbloc-webapp-${var.environment}"
  image          = var.app_image
  container_port = var.app_port
  replicas       = var.app_replicas

  labels = {
    env = local.env
  }

  enable_static_html = true
  html_path          = local.html_abs_path

  node_port = var.node_port

  # NEW: tunnel for this app only
  enable_cloudflared           = true
  cloudflared_tunnel_id        = "109c1cc5-0788-4761-bbe6-06cfd05c769f"
  cloudflared_hostname         = "cloudbloc.io"
  cloudflared_credentials_json = file("${path.module}/credentials.json")

}
