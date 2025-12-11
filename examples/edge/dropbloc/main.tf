module "dropbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/dropbloc?ref=edge-dropbloc-v0.2.0"
  # source = "../../../blocs/edge/dropbloc"

  namespace      = "dropbloc"
  node_ip        = "10.0.0.187" # LAN IP
  data_host_path = "/mnt/dropbloc/nextcloud-data"
  data_size      = "800Gi"

  # Used by cloudflared as the public hostname
  nextcloud_hostname = "dropbloc.cloudbloc.io"

  nextcloud_canonical_host     = "10.0.0.187:30080"
  nextcloud_canonical_protocol = "http"

  admin_username = "admin"
  admin_password = "supersecurepassword"

  service_node_port = 30080

  enable_cloudflared           = true
  cloudflared_credentials_file = abspath("${path.module}/credentials.json")
  cloudflared_tunnel_id        = "26b4d1ec-384f-477e-a404-f3d7352b45db"
}
