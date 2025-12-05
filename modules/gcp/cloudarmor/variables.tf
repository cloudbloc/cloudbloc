variable "name" {
  description = "Security policy name"
  type        = string
}

variable "description" {
  description = "Security policy description"
  type        = string
  default     = "Cloud Armor for public access"
}

variable "block_cidrs" {
  description = "List of CIDRs to explicitly block"
  type        = list(string)
  default     = []
}

variable "rate_limit_count" {
  description = "Requests per interval before throttling"
  type        = number
  default     = 120
}

variable "rate_limit_interval_sec" {
  description = "Interval in seconds for rate_limit_count"
  type        = number
  default     = 60
}

variable "ban_threshold_count" {
  description = "Requests per interval that trigger a temporary ban"
  type        = number
  default     = 240
}

variable "ban_threshold_interval_sec" {
  description = "Interval in seconds for ban_threshold_count"
  type        = number
  default     = 60
}

variable "ban_duration_sec" {
  description = "Temporary ban duration in seconds"
  type        = number
  default     = 600
}
