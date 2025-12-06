output "grafana_hostnames" {
  description = "Grafana hostnames served by the Ingress"
  value       = var.domains
}

output "edge_ip" {
  description = "Global static IP address"
  value       = google_compute_global_address.edge_ip.address
}
