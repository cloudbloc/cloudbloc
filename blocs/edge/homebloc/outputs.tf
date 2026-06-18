output "remote_root" {
  description = "Remote directory containing the installed HomeBloc compose stack."
  value       = var.remote_root
}

output "homebloc_root" {
  description = "Persistent host path for Home Assistant config data."
  value       = local.homebloc_root
}

output "service_urls" {
  description = "HomeBloc service endpoints."
  value = {
    home_assistant = "http://${local.service_host}:${var.http_port}"
  }
}
