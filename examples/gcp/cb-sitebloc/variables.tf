variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "potent-thought-470914-t1"
}

variable "environment" {
  description = "Environment name (e.g., dev, stg, prd)"
  type        = string
  default     = "prd"
}

variable "region" {
  description = "The GCP region to deploy resources in"
  type        = string
  default = "us-east-1"
}

variable "site_name" {
  description = "The name of the Google Cloud Storage bucket for static site hosting."
  type        = string
  default = "sitebloc.cloudbloc.io"
}

variable "location" {
  description = "The location where the bucket will be created."
  type        = string
  default     = "US"
}

variable "website_main_page_suffix" {
  description = "The main page suffix for the static website."
  type        = string
  default     = "index.html"
}

variable "website_not_found_page" {
  description = "The 404 page for the static website."
  type        = string
  default     = "404.html"
}
