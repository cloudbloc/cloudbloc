variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "potent-thought-470914-t1"
}

variable "region" {
  description = "The GCP region to deploy resources in"
  type        = string
}

variable "location" {
  description = "GKE location (use a ZONE like us-central1-a for cheapest)"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name (e.g., dev, stg, prd)"
  type        = string
  default     = "prd"
}

variable "cluster_name" {
  description = "The GKE cluster name"
  type        = string
  default     = "cloudbloc-gke-prd"
}

variable "app_name" {
  description = "Base name used for Grafana resources (svc/ingress/cert)"
  type        = string
  default     = "obsbloc"
}

variable "edge_ip_name" {
  description = "The edge IP name"
  type        = string
  default     = "obsbloc-edge-ip"
}

variable "namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "obsbloc"
}

variable "domains" {
  type    = list(string)
  default = ["obsbloc.cloudbloc.io", "www.obsbloc.cloudbloc.io"]
}

variable "replicas" {
  description = "Grafana replicas"
  type        = number
  default     = 1
}

variable "zone_name" {
  description = "Existing Cloud DNS managed zone NAME (not DNS name). Example: 'cloudbloc-io'"
  type        = string
  default     = "cloudbloc-io"
}

variable "security_policy_name" {
  type        = string
  description = "Cloud Armor security policy name to attach to the Ingress"
  default = "edge-armor-shared"
}
