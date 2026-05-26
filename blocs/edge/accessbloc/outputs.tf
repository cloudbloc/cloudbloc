output "namespace" {
  description = "Namespace where AccessBloc is deployed."
  value       = var.namespace
}

output "deployment_name" {
  description = "AccessBloc Deployment name."
  value       = kubernetes_deployment_v1.this.metadata[0].name
}

output "auth_key_secret_name" {
  description = "Secret name used for the Tailscale auth key."
  value       = var.auth_key_secret_name
}

output "tailscale_hostname" {
  description = "Hostname registered in the tailnet."
  value       = var.tailscale_hostname
}

output "advertise_routes" {
  description = "Routes advertised by AccessBloc."
  value       = var.advertise_routes
}
