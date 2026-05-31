variable "host" {
  description = "Target edge host reachable over LAN or private network."
  type        = string
}

variable "ssh_user" {
  description = "SSH user on the target edge host."
  type        = string
}

variable "ssh_port" {
  description = "SSH port on the target edge host."
  type        = number
  default     = 22
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
  description = "Remote directory where GuardBloc compose files are installed."
  type        = string
  default     = "/opt/guardbloc"
}
variable "guardbloc_root" {
  description = "Optional persistent host path for GuardBloc config/work data. Defaults to /var/lib/guardbloc."
  type        = string
  default     = null
}

variable "service_bind_ip" {
  description = "Host IP address for AdGuard DNS and web UI ports. Use the edge host LAN IP for LAN DNS."
  type        = string
}

variable "dns_port" {
  description = "Host port for AdGuard DNS over TCP and UDP."
  type        = number
  default     = 53
}

variable "http_port" {
  description = "Host port for the AdGuard setup/admin UI."
  type        = number
  default     = 3000
}

variable "adguard_version" {
  description = "AdGuard Home container image tag."
  type        = string
  default     = "latest"
}

variable "install_docker" {
  description = "Whether the deploy script should install Docker on Ubuntu/Debian if Docker is missing."
  type        = bool
  default     = true
}
