variable "namespace" {
  type        = string
  description = "Kubernetes namespace for Nextcloud + cloudflared."
  default     = "dropbloc"
}

variable "data_host_path" {
  type        = string
  description = "Host path on local to store Nextcloud data (photos, videos, files)."
  default     = "/mnt/dropbloc/nextcloud-data"
}

variable "data_size" {
  type        = string
  description = "Requested storage size for Nextcloud data."
  default     = "800Gi"
}

variable "storage_class_name" {
  type        = string
  description = "StorageClass name for the local hostPath PV."
  default     = "nextcloud-local-storage"
}

variable "chart_version" {
  type        = string
  description = "Nextcloud Helm chart version."
  default     = "8.6.0"
}

variable "service_node_port" {
  type        = number
  description = "NodePort for accessing Nextcloud on the LAN."
  default     = 30080
}

variable "node_ip" {
  type        = string
  description = "LAN IP address of the local node that exposes the NodePort."
}

variable "nextcloud_hostname" {
  type        = string
  description = "Public hostname (Cloudflare) for Nextcloud."
}

variable "admin_username" {
  type        = string
  description = "Nextcloud admin username."
}

variable "admin_password" {
  type        = string
  description = "Nextcloud admin password."
  sensitive   = true
}

variable "php_memory_limit" {
  type        = string
  description = "PHP memory_limit."
  default     = "2048M"
}

variable "php_upload_limit" {
  type        = string
  description = "PHP upload_max_filesize / post_max_size."
  default     = "16G"
}

variable "php_max_execution_time" {
  type        = string
  description = "PHP max_execution_time / max_input_time in seconds."
  default     = "3600"
}

variable "enable_cloudflared" {
  type        = bool
  description = "Whether to deploy Cloudflared tunnel for public HTTPS access."
  default     = true
}

variable "cloudflared_tunnel_id" {
  type        = string
  description = "Cloudflare Tunnel ID."
  default     = ""
}

variable "cloudflared_credentials_file" {
  type        = string
  description = "Path to the Cloudflare tunnel credentials.json on the machine running Terraform."
  default     = ""
}

variable "nextcloud_canonical_host" {
  type        = string
  description = <<-EOT
Canonical host Nextcloud should use for generated links/redirects (OVERWRITEHOST + extra trustedDomain).
If empty, defaults to nextcloud_hostname.
EOT
  default     = ""
}

variable "nextcloud_canonical_protocol" {
  type        = string
  description = "Protocol for generated URLs (OVERWRITEPROTOCOL). Usually http or https."
  default     = "https"
}

