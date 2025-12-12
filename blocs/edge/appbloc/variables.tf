##########
# Core app variables
##########

variable "namespace" {
  description = "Kubernetes namespace to deploy the app into"
  type        = string
}

variable "app_name" {
  description = "Application name (used for Deployment/Service names)"
  type        = string
}

variable "image" {
  description = "Container image (e.g., nginx:stable)"
  type        = string
  default     = "nginx:stable"
}

variable "container_port" {
  description = "Container port to expose"
  type        = number
}

variable "replicas" {
  description = "Number of replicas"
  type        = number
  default     = 1
}

variable "labels" {
  description = "Additional labels to add to resources"
  type        = map(string)
  default     = {}
}

variable "env" {
  description = "Environment variables for the container (non-secret)."
  type        = map(string)
  default     = {}
}

variable "enable_static_html" {
  description = "Mount an index.html from a ConfigMap at /usr/share/nginx/html"
  type        = bool
  default     = false
}

variable "html_path" {
  description = "Path to the HTML file to serve (relative to the Terraform root)."
  type        = string
  default     = "index.html"

  validation {
    condition     = length(var.html_path) > 0
    error_message = "html_path must be a non-empty string."
  }
}

variable "node_port" {
  description = "NodePort to expose the service on (in the 30000-32767 range)."
  type        = number
  default     = 30081
}

##########
# Cloudflare tunnel variables
##########

variable "enable_cloudflared" {
  description = "Deploy an in-cluster Cloudflare tunnel for this app"
  type        = bool
  default     = false
}

variable "cloudflared_tunnel_id" {
  description = "Cloudflare tunnel UUID (no braces)"
  type        = string
  default     = null
}

variable "cloudflared_hostname" {
  description = "Public hostname for this app (e.g. cloudbloc.io)"
  type        = string
  default     = null
}

variable "cloudflared_credentials_json" {
  description = "Contents of the Cloudflare tunnel credentials JSON"
  type        = string
  sensitive   = true
  default     = null
}

##########
# Worker / CronJob variables
##########

variable "enable_worker" {
  description = "Enable a worker CronJob for background/automation tasks"
  type        = bool
  default     = false
}

variable "worker_image" {
  description = "Container image for the worker (defaults to web image if empty)"
  type        = string
  default     = ""
}

variable "worker_schedule" {
  description = "Cron schedule for the worker (e.g. \"*/5 * * * *\" for every 5 minutes)"
  type        = string
  default     = "0 * * * *" # every hour by default
}

variable "worker_command" {
  description = "Optional command for the worker container"
  type        = list(string)
  default     = []
}

variable "worker_args" {
  description = "Optional args for the worker container"
  type        = list(string)
  default     = []
}

variable "worker_env" {
  description = "Environment variables for the worker. If empty, inherits env from the web app."
  type        = map(string)
  default     = {}
}

variable "worker_input_host_path" {
  description = "Optional hostPath on the node to mount at /input in the worker container."
  type        = string
  default     = null
}

variable "worker_output_host_path" {
  description = "Optional hostPath on the node to mount at /output in the worker container."
  type        = string
  default     = null
}

variable "worker_env_from_secret" {
  description = "Map of ENV_VAR_NAME -> secret name. Secret key must match the env var name."
  type        = map(string)
  default     = {}
}

variable "worker_image_pull_secret" {
  description = "Optional imagePullSecret name for pulling private images."
  type        = string
  default     = null
}

variable "worker_restart_policy" {
  description = "Pod restart policy for the worker job"
  type        = string
  default     = "OnFailure"
}

variable "worker_backoff_limit" {
  description = "How many times Kubernetes should retry a failed job"
  type        = number
  default     = 3
}

variable "worker_concurrency_policy" {
  description = "Concurrency policy for the CronJob: Allow, Forbid, or Replace"
  type        = string
  default     = "Forbid"
}

variable "worker_successful_jobs_history_limit" {
  description = "How many successful jobs to keep"
  type        = number
  default     = 1
}

variable "worker_failed_jobs_history_limit" {
  description = "How many failed jobs to keep"
  type        = number
  default     = 3
}

variable "worker_requests_cpu" {
  description = "CPU requests for worker container"
  type        = string
  default     = "100m"
}

variable "worker_requests_memory" {
  description = "Memory requests for worker container"
  type        = string
  default     = "256Mi"
}

variable "worker_limits_cpu" {
  description = "CPU limits for worker container"
  type        = string
  default     = "500m"
}

variable "worker_limits_memory" {
  description = "Memory limits for worker container"
  type        = string
  default     = "512Mi"
}
