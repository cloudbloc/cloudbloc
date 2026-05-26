variable "namespace" {
  description = "Kubernetes namespace for AccessBloc."
  type        = string
  default     = "accessbloc"
}

variable "tailscale_hostname" {
  description = "Hostname to register in the tailnet."
  type        = string
  default     = "tiny-accessbloc"
}

variable "create_namespace" {
  description = "Whether Terraform should create the namespace. Keep false when the auth-key Secret is pre-created manually."
  type        = bool
  default     = false
}

variable "auth_key_secret_name" {
  description = "Existing Secret containing TS_AUTHKEY."
  type        = string
  default     = "tailscale-auth"
}

variable "advertise_routes" {
  description = "CIDR routes to advertise through this Tiny."
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "advertise_exit_node" {
  description = "Whether to advertise this Tiny as an exit node."
  type        = bool
  default     = false
}

variable "enable_ssh" {
  description = "Whether to enable Tailscale SSH."
  type        = bool
  default     = false
}
