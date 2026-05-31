module "guardbloc" {
  source = "../../../blocs/edge/guardbloc"

  host                 = var.host
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_agent            = var.ssh_agent

  remote_root    = var.remote_root
  guardbloc_root = var.guardbloc_root

  service_bind_ip = var.service_bind_ip
  dns_port        = var.dns_port
  http_port       = var.http_port
  install_docker  = var.install_docker
}
