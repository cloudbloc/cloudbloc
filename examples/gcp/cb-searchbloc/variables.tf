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

variable "namespace" {
  description = "Kubernetes namespace to deploy SearchBloc into. Must match ObsBloc namespace if using the same Ingress."
  type        = string
  default     = "obsbloc"
}

variable "app_name" {
  description = "Base name used for SearchBloc resources (Deployment, Service, ConfigMaps, etc.)."
  type        = string
  default     = "searchbloc"
}

variable "labels" {
  description = "Extra labels to attach to all SearchBloc resources."
  type        = map(string)
  default     = {}
}

variable "replicas" {
  description = "Number of Meilisearch replicas. Use 1 for cheapest deployment."
  type        = number
  default     = 1
}

variable "image" {
  description = "Meilisearch container image."
  type        = string
  default     = "getmeili/meilisearch:v1.11.1"
}

variable "storage_size" {
  description = "PersistentVolumeClaim size for Meilisearch data."
  type        = string
  default     = "10Gi"
}

variable "storage_class_name" {
  description = "StorageClass name to use for the PVC."
  type        = string
  default     = "standard-rwo"
}

variable "resources" {
  description = "CPU and memory requests/limits for the Meilisearch container."
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
  })
  default = {
    requests_cpu    = "250m"
    requests_memory = "512Mi"
    limits_cpu      = "500m"
    limits_memory   = "1Gi"
  }
}

variable "master_key" {
  description = "Meilisearch master key (used to create other API keys). Keep this secret."
  type        = string
  sensitive   = true
}

variable "public_search_key" {
  description = "Public read-only Meilisearch API key injected into the demo UI (never use master key). Leave empty for unsecured/demo."
  type        = string
  default     = ""
}
