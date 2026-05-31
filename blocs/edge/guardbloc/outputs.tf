output "remote_root" {
  description = "Remote directory containing the installed GuardBloc compose stack."
  value       = var.remote_root
}

output "guardbloc_root" {
  description = "Persistent host path for GuardBloc config/work data."
  value       = local.guardbloc_root
}

output "service_urls" {
  description = "GuardBloc service endpoints."
  value = {
    adguard_ui = "http://${var.service_bind_ip}:${var.http_port}"
    dns_tcp    = "${var.service_bind_ip}:${var.dns_port}/tcp"
    dns_udp    = "${var.service_bind_ip}:${var.dns_port}/udp"
  }
}
