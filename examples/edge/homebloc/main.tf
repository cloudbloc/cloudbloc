module "homebloc" {
  source = "../../../blocs/edge/homebloc"

  host                 = var.host
  ssh_user             = var.ssh_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_agent            = var.ssh_agent

  remote_root   = var.remote_root
  homebloc_root = var.homebloc_root

  service_host           = var.service_host
  http_port              = var.http_port
  timezone               = var.timezone
  home_assistant_version = var.home_assistant_version
  privileged             = var.privileged

  install_docker = var.install_docker
}
