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

variable "html_path" {
  description = "Path to the HTML file to serve (relative to the Terraform root)."
  type        = string
  default     = "index.html"

  validation {
    condition     = length(var.html_path) > 0
    error_message = "html_path must be a non-empty string."
  }
}

# Optional: name of an existing Cloud Armor policy to attach
variable "cloudarmor_policy" {
  description = "Cloud Armor security policy name to attach to the GCE Ingress"
  type        = string
  default     = null
}

# Optional: let callers add any extra annotations
variable "extra_ingress_annotations" {
  description = "Additional annotations to merge into the Ingress"
  type        = map(string)
  default     = {}
}
