output "service_name" {
  description = "Kubernetes Service name"
  value       = kubernetes_service_v1.web.metadata[0].name
}

output "service_namespace" {
  description = "Namespace where the Service is deployed"
  value       = kubernetes_namespace_v1.namespace.metadata[0].name
}

output "service_node_port" {
  description = "NodePort used to access the app on the homelab node"
  value       = kubernetes_service_v1.web.spec[0].port[0].node_port
}
