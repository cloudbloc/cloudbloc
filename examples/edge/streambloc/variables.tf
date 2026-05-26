variable "tiny_host" {
  description = "Tiny host reachable over LAN or Tailscale."
  type        = string
  default     = "10.0.0.187"
}

variable "tiny_user" {
  description = "SSH user on the Tiny."
  type        = string
  default     = "yprk"
}

variable "ssh_private_key_path" {
  description = "Optional path to an SSH private key. Leave empty to use ssh-agent/default SSH behavior."
  type        = string
  default     = ""
}

variable "ssh_agent" {
  description = "Whether Terraform should use the local SSH agent when ssh_private_key_path is empty."
  type        = bool
  default     = true
}

variable "remote_root" {
  description = "Remote directory where StreamBloc compose files are installed."
  type        = string
  default     = "/opt/streambloc"
}

variable "storage_root" {
  description = "Persistent SSD mount root used by StreamBloc."
  type        = string
  default     = "/mnt/dropbloc"
}

variable "require_storage_mount" {
  description = "Whether deployment should fail if storage_root is not an active mount point."
  type        = bool
  default     = true
}

variable "streambloc_root" {
  description = "Optional persistent host path for StreamBloc app config. Defaults to storage_root/streambloc."
  type        = string
  default     = null
}

variable "media_root" {
  description = "Optional persistent host path for StreamBloc media and downloads. Defaults to storage_root/streambloc-media."
  type        = string
  default     = null
}

variable "bind_ip" {
  description = "IP address for published service ports. Use 0.0.0.0 for LAN plus Tailscale, or the Tiny Tailscale IP for tailnet-only."
  type        = string
  default     = "0.0.0.0"
}

variable "jellyfin_public_url" {
  description = "Public URL Jellyfin should advertise to clients."
  type        = string
  default     = "http://10.0.0.187:8096"
}

variable "enable_hwaccel" {
  description = "Whether to include the Intel QuickSync/VAAPI compose override when /dev/dri exists."
  type        = bool
  default     = true
}

variable "install_docker" {
  description = "Whether the deploy script should install Docker on Ubuntu/Debian if Docker is missing."
  type        = bool
  default     = true
}
