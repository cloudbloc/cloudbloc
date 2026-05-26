module "streambloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/streambloc?ref=edge-streambloc-v0.1.0"
  # source = "../../../blocs/edge/streambloc"

  tiny_host            = var.tiny_host
  tiny_user            = var.tiny_user
  ssh_private_key_path = var.ssh_private_key_path
  ssh_agent            = var.ssh_agent

  remote_root           = var.remote_root
  storage_root          = var.storage_root
  require_storage_mount = var.require_storage_mount
  streambloc_root       = var.streambloc_root
  media_root            = var.media_root
  bind_ip               = var.bind_ip
  jellyfin_public_url   = var.jellyfin_public_url

  enable_hwaccel = var.enable_hwaccel
  install_docker = var.install_docker
}
