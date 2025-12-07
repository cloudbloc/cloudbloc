output "namespace" {
  description = "Namespace where Nextcloud is installed"
  value       = var.namespace
}

output "url" {
  description = "URL to access Nextcloud (if domain is set)"
  value       = var.domain != "" ? "https://${var.domain}" : ""
}
