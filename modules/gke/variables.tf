variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "location" {
  description = "GKE location (use a ZONE like us-central1-a for cheapest)"
  type        = string
}

variable "name" {
  description = "Cluster name"
  type        = string
}

variable "release_channel" {
  description = "GKE release channel (RAPID, REGULAR, STABLE)"
  type        = string
  default     = "STABLE"
}

# ---- Mode ----
variable "enable_autopilot" {
  description = "If true, create an Autopilot cluster (cheapest for small/demo)"
  type        = bool
  default     = false
}

# ---- Standard mode (cheap profile) ----
variable "min_nodes" {
  description = "Minimum nodes (allow 0 to scale to zero when idle)"
  type        = number
  default     = 0
}

variable "max_nodes" {
  description = "Maximum nodes"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Node machine type (e2-small is stable & cheap; e2-micro is possible but tight)"
  type        = string
  default     = "e2-small"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "spot" {
  description = "Use Spot (preemptible) nodes for big savings"
  type        = bool
  default     = true
}
