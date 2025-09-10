output "service_name" {
  description = "Kubernetes Service name for Meilisearch."
  value       = kubernetes_service.meili.metadata[0].name
}

output "cluster_url" {
  description = "In-cluster URL for Meilisearch."
  value       = "http://${kubernetes_service.meili.metadata[0].name}.${var.namespace}.svc.cluster.local:7700"
}
