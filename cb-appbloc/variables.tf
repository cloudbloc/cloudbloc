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

variable "edge_ip_name" {
  description = "The edge IP name"
  type        = string
  default     = "cloudbloc-edge-ip"
}

variable "app_namespace" {
  description = "Kubernetes namespace for the app"
  type        = string
  default     = "appbloc"
}

variable "app_image" {
  description = "Container image for the app"
  type        = string
  default     = "nginx:stable"
}

variable "app_port" {
  description = "Container port"
  type        = number
  default     = 80
}

variable "app_replicas" {
  description = "Replica count"
  type        = number
  default     = 1
}

variable "service_type" {
  description = "Kubernetes Service type (LoadBalancer | ClusterIP | NodePort)"
  type        = string
  default     = "LoadBalancer"
}

variable "domains" {
  type    = list(string)
  default = ["cloudbloc.io", "www.cloudbloc.io"]
}
