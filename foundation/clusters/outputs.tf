output "gke_name" {
  value       = module.gke.name
  description = "Cluster name"
}

output "gke_endpoint" {
  value       = module.gke.endpoint   # NOTE: your module already includes "https://"
  description = "API endpoint"
}

output "gke_ca_certificate" {
  value       = module.gke.ca_certificate
  sensitive   = true
  description = "Cluster CA cert (base64)"
}
