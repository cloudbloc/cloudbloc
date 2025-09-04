variable "namespace" {
  description = "Kubernetes namespace to deploy the app into"
  type        = string
}

variable "edge_ip_name" {
  type = string
}

variable "app_name" {
  description = "Application name (used for Deployment/Service names)"
  type        = string
}

variable "image" {
  description = "Container image (e.g., nginx:stable)"
  type        = string
  default     = "nginx:stable"
}

variable "container_port" {
  description = "Container port to expose"
  type        = number
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 2
}

variable "service_type" {
  description = "Service type (LoadBalancer | ClusterIP | NodePort)"
  type        = string
  default     = "LoadBalancer"
}

variable "labels" {
  description = "Additional labels to add to resources"
  type        = map(string)
  default     = {}
}

variable "domains" {
  type = list(string)
}
