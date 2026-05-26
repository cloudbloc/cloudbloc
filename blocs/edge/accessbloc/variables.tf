variable "namespace" {
  description = "Kubernetes namespace for AccessBloc."
  type        = string
  default     = "accessbloc"
}

variable "create_namespace" {
  description = "Whether Terraform should create the namespace. Set false when pre-creating the namespace and auth-key Secret outside Terraform."
  type        = bool
  default     = true
}

variable "app_name" {
  description = "Name used for AccessBloc Kubernetes resources."
  type        = string
  default     = "accessbloc"
}

variable "image" {
  description = "Tailscale container image."
  type        = string
  default     = "tailscale/tailscale:stable"
}

variable "labels" {
  description = "Additional labels to attach to AccessBloc resources."
  type        = map(string)
  default     = {}
}

variable "auth_key" {
  description = "Optional Tailscale auth key. Prefer pre-creating a Kubernetes Secret and setting auth_key_secret_name to avoid storing this in Terraform state."
  type        = string
  sensitive   = true
  default     = null
}

variable "auth_key_secret_name" {
  description = "Name of an existing Secret containing the Tailscale auth key. The key must be auth_key_secret_key."
  type        = string
  default     = "tailscale-auth"
}

variable "auth_key_secret_key" {
  description = "Key inside auth_key_secret_name that contains the Tailscale auth key."
  type        = string
  default     = "TS_AUTHKEY"
}

variable "tailscale_hostname" {
  description = "Hostname to register in the tailnet."
  type        = string
  default     = "accessbloc"
}

variable "advertise_routes" {
  description = "CIDR routes to advertise through this node, for example the Tiny LAN CIDR."
  type        = list(string)
  default     = []
}

variable "accept_routes" {
  description = "Whether this node should accept routes advertised by other tailnet nodes."
  type        = bool
  default     = false
}

variable "advertise_exit_node" {
  description = "Whether to advertise this node as a tailnet exit node."
  type        = bool
  default     = false
}

variable "enable_ssh" {
  description = "Whether to enable Tailscale SSH for this node."
  type        = bool
  default     = false
}

variable "extra_args" {
  description = "Additional tailscale up arguments."
  type        = list(string)
  default     = []
}

variable "host_network" {
  description = "Run the Tailscale pod in the host network namespace. Recommended for Tiny subnet-router deployments."
  type        = bool
  default     = true
}

variable "privileged" {
  description = "Run the Tailscale container as privileged. Useful on edge clusters where /dev/net/tun or routing needs elevated access."
  type        = bool
  default     = true
}

variable "state_storage_size" {
  description = "PVC size for Tailscale state."
  type        = string
  default     = "1Gi"
}

variable "state_storage_class_name" {
  description = "StorageClass name for the state PVC. Set to null for cluster default."
  type        = string
  default     = null
}

variable "resources" {
  description = "CPU and memory requests/limits for the Tailscale container."
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
  })
  default = {
    requests_cpu    = "50m"
    requests_memory = "128Mi"
    limits_cpu      = "250m"
    limits_memory   = "256Mi"
  }
}
