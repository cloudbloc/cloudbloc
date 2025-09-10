variable "namespace" {
  description = "Kubernetes namespace to deploy SearchBloc into."
  type        = string
}

variable "app_name" {
  description = "Name for the Meilisearch app/deployment/service."
  type        = string
  default     = "searchbloc"
}

variable "labels" {
  description = "Extra labels to add to resources."
  type        = map(string)
  default     = {}
}

variable "replicas" {
  description = "Number of Meilisearch replicas (1 for cheapest)."
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
  description = "CPU/memory requests and limits for the Meilisearch container."
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
  description = "Meilisearch master key (used to derive other keys)."
  type        = string
  sensitive   = true
}

variable "public_search_key" {
  description = "Public read-only Meilisearch API key injected into the demo UI (never use master key). Leave empty for unsecured/demo."
  type        = string
  default     = ""
}
