module "dropbloc" {
  source = "../../../blocs/edge/dropbloc"

  namespace      = "dropbloc"
  domain         = "" # no ingress for now (Cloudflare Tunnel only)
  admin_username = "admin"
  admin_password = "super-secret"

  # pass an ABSOLUTE path so the module can read it
  cloudflared_credentials_file = abspath("${path.module}/credentials.json")
  cloudflared_tunnel_id        = "26b4d1ec-384f-477e-a404-f3d7352b45db"

}
