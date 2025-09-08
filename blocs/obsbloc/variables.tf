variable "namespace" {
  description = "Kubernetes namespace for ObsBloc"
  type        = string
}

variable "edge_ip_name" {
  description = "Name of the global static IP for the GCE Ingress"
  type        = string
}

variable "app_name" {
  description = "Base name used for Grafana resources (svc/ingress/cert)"
  type        = string
  default     = "obsbloc"
}

variable "replicas" {
  description = "Grafana replicas"
  type        = number
  default     = 1
}

variable "labels" {
  description = "Labels applied to resources"
  type        = map(string)
  default     = {}
}

variable "domains" {
  description = "Hostnames served by this Ingress (e.g., [\"obsbloc.cloudbloc.io\"])"
  type        = list(string)
}

variable "grafana_image" {
  description = "Grafana container image"
  type        = string
  default     = "grafana/grafana:latest"
}

variable "prometheus_image" {
  description = "Prometheus container image"
  type        = string
  default     = "prom/prometheus:v2.53.0"
}

# Use an existing Cloud DNS managed zone (do NOT create a zone here)
variable "zone_name" {
  description = "Existing Cloud DNS managed zone NAME (not DNS name). Example: 'cloudbloc-io'"
  type        = string

  validation {
    condition     = length(var.zone_name) > 0
    error_message = "zone_name must be a non-empty managed zone NAME."
  }
}

# Optional: name of an existing Cloud Armor policy to attach
variable "cloudarmor_policy" {
  description = "Cloud Armor security policy name to attach to the GCE Ingress"
  type        = string
  default     = null
}

# Optional: let callers add any extra annotations
variable "extra_ingress_annotations" {
  description = "Additional annotations to merge into the Ingress"
  type        = map(string)
  default     = {}
}
