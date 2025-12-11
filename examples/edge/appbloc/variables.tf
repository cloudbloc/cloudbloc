variable "environment" {
  description = "Environment name (e.g., dev, stg, prd)"
  type        = string
  default     = "prd"
}
variable "app_namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "appbloc"
}

variable "app_image" {
  description = "Container image for the app"
  type        = string
  default     = "nginx:stable"
}

variable "app_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "app_replicas" {
  description = "Replica count"
  type        = number
  default     = 1
}

variable "html_path" {
  description = "Path to the HTML file to serve (under ./static; the root module will combine it with path.root/static)."
  type        = string
  default     = "index.html"
}


variable "node_port" {
  description = "NodePort to expose the app on (LAN / Cloudflare tunnel, 30000–32767)."
  type        = number
  default     = 30081
}

# Optional: keep domains at root if you want to reuse them for CF DNS/Tunnel config
variable "domains" {
  description = "Domains/hostnames for this app, used by Cloudflare (not by Kubernetes)."
  type        = list(string)
  default     = ["cloudbloc.io", "www.cloudbloc.io"]
}

