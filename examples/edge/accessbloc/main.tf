module "accessbloc" {
  source = "../../../blocs/edge/accessbloc"

  namespace            = var.namespace
  create_namespace     = var.create_namespace
  app_name             = "accessbloc"
  tailscale_hostname   = var.tailscale_hostname
  auth_key_secret_name = var.auth_key_secret_name

  advertise_routes    = var.advertise_routes
  advertise_exit_node = var.advertise_exit_node
  enable_ssh          = var.enable_ssh

  labels = {
    bloc = "accessbloc"
    env  = "prd"
  }
}
