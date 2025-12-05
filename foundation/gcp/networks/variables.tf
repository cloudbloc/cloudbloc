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
