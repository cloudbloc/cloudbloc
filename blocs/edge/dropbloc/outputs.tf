output "nextcloud_lan_url" {
  description = "LAN URL for Nextcloud."
  value       = "http://${var.node_ip}:${var.service_node_port}"
}

output "nextcloud_public_url" {
  description = "Public URL for Nextcloud (via Cloudflare)."
  value       = var.nextcloud_hostname
}
