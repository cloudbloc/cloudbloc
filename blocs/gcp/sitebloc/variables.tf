variable "site_name" {
  description = "The name of the Google Cloud Storage bucket for static site hosting."
  type        = string
}

variable "location" {
  description = "The location where the Google Cloud Storage bucket will be created."
  type        = string
  default     = "US"
}

variable "website_main_page_suffix" {
  description = "The main page suffix for the static website (e.g., index.html)."
  type        = string
  default     = "index.html"
}

variable "website_not_found_page" {
  description = "The page to serve when a requested page is not found."
  type        = string
  default     = "404.html"
}

variable "cors_configuration" {
  description = "CORS configuration for the bucket."
  type = list(object({
    origin          = list(string)
    method          = list(string)
    max_age_seconds = number
  }))
  default = []
}
