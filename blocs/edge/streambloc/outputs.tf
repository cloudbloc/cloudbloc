output "remote_root" {
  description = "Remote directory containing the installed StreamBloc compose stack."
  value       = var.remote_root
}

output "streambloc_root" {
  description = "Persistent host path for StreamBloc app config."
  value       = local.streambloc_root
}

output "media_root" {
  description = "Persistent host path for StreamBloc media and downloads."
  value       = local.media_root
}

output "service_urls" {
  description = "Default StreamBloc service URLs."
  value = {
    jellyfin    = "http://${var.tiny_host}:8096"
    sonarr      = "http://${var.tiny_host}:8989"
    radarr      = "http://${var.tiny_host}:7878"
    prowlarr    = "http://${var.tiny_host}:9696"
    bazarr      = "http://${var.tiny_host}:6767"
    qbittorrent = "http://${var.tiny_host}:8080"
  }
}
