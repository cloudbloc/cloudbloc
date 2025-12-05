output "edge_ip_name" {
  description = "Global static IP resource name for GCE Ingress"
  value       = google_compute_global_address.app_edge_ip.name
}

output "edge_ip_addr" {
  description = "Global static IP address"
  value       = google_compute_global_address.app_edge_ip.address
}

output "dns_zone_name" {
  value       = local.zone_name
  description = "Active Cloud DNS zone name"
}

