variable "namespace" {
  description = "Kubernetes namespace for Nextcloud"
  type        = string
  default     = "dropbloc"
}

variable "chart_version" {
  description = "The Helm chart version for Nextcloud"
  type        = string
  default     = "8.6.0"
}

variable "domain" {
  description = "Hostname for Nextcloud ingress (leave empty to disable ingress)"
  type        = string
  default     = ""
}

variable "admin_username" {
  description = "Nextcloud admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Nextcloud admin password"
  type        = string
  sensitive   = true
  default     = "changeme-please"
}

variable "cloudflared_credentials_file" {
  type        = string
  description = "Path to the Cloudflare tunnel credentials.json file"
}

variable "nextcloud_service_port" {
  type    = number
  default = 80
}

variable "nextcloud_hostname" {
  type    = string
  default = "dropbloc.cloudbloc.io"
}

variable "cloudflared_tunnel_id" {
  type        = string
  description = "Cloudflare tunnel ID (UUID), not the name"
}

variable "nextcloud_service_name" {
  type    = string
  default = "nextcloud"
}
