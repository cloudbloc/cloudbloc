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
  description = "Remote directory where HomeBloc compose files are installed."
  type        = string
  default     = "/opt/homebloc"
}

variable "homebloc_root" {
  description = "Optional persistent host path for Home Assistant config data. Defaults to /var/lib/homebloc."
  type        = string
  default     = null
}

variable "service_host" {
  description = "Host/IP users should open for Home Assistant. Defaults to host."
  type        = string
  default     = null
}

variable "http_port" {
  description = "Home Assistant HTTP port. Host networking is used, so this must match Home Assistant's configured listen port."
  type        = number
  default     = 8123
}

variable "timezone" {
  description = "IANA timezone passed to the Home Assistant container."
  type        = string
  default     = "UTC"
}

variable "home_assistant_version" {
  description = "Home Assistant container image tag."
  type        = string
  default     = "stable"
}

variable "privileged" {
  description = "Whether to run the Home Assistant container in privileged mode for local devices and discovery."
  type        = bool
  default     = true
}

variable "install_docker" {
  description = "Whether the deploy script should install Docker on Ubuntu/Debian if Docker is missing."
  type        = bool
  default     = true
}
