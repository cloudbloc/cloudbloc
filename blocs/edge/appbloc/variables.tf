
variable "namespace" {
  description = "Kubernetes namespace to deploy the app into"
  type        = string
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
  default     = 1
}

variable "labels" {
  description = "Additional labels to add to resources"
  type        = map(string)
  default     = {}
}

variable "env" {
  description = "Environment variables for the container (non-secret)."
  type        = map(string)
  default     = {}
}

variable "enable_static_html" {
  description = "Mount an index.html from a ConfigMap at /usr/share/nginx/html"
  type        = bool
  default     = false
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

variable "node_port" {
  description = "NodePort to expose the service on (in the 30000-32767 range)."
  type        = number
  default     = 30081
}

variable "enable_cloudflared" {
  description = "Deploy an in-cluster Cloudflare tunnel for this app"
  type        = bool
  default     = false
}

variable "cloudflared_tunnel_id" {
  description = "Cloudflare tunnel UUID (no braces)"
  type        = string
  default     = null
}

variable "cloudflared_hostname" {
  description = "Public hostname for this app (e.g. cloudbloc.io)"
  type        = string
  default     = null
}

variable "cloudflared_credentials_json" {
  description = "Contents of the Cloudflare tunnel credentials JSON"
  type        = string
  sensitive   = true
  default     = null
}
