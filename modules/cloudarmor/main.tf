locals {
  # HTTPS LB health check source ranges (keep these up to date if GCP adds ranges)
  gclb_healthcheck_cidrs = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
}

resource "google_compute_security_policy" "this" {
  name        = var.name
  description = var.description

  # 0) Always allow Google health checks
  rule {
    priority = 800
    action   = "allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = local.gclb_healthcheck_cidrs
      }
    }
    description = "Allow GCLB health checks"
  }

  # 1) Optional explicit blocklist
  dynamic "rule" {
    for_each = length(var.block_cidrs) > 0 ? [1] : []
    content {
      priority = 900
      action   = "deny(403)"
      match {
        versioned_expr = "SRC_IPS_V1"
        config {
          src_ip_ranges = var.block_cidrs
        }
      }
      description = "Block specific CIDRs"
    }
  }

  # 2) Per-IP rate limit with temporary ban on abuse
  rule {
    priority = 1200
    action   = "rate_based_ban"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      enforce_on_key = "IP"

      rate_limit_threshold {
        count        = var.rate_limit_count
        interval_sec = var.rate_limit_interval_sec
      }

      conform_action = "allow"
      exceed_action  = "deny(429)"

      ban_threshold {
        count        = var.ban_threshold_count
        interval_sec = var.ban_threshold_interval_sec
      }
      ban_duration_sec = var.ban_duration_sec
    }
    description = "Global per-IP rate limit for public access"
  }

  # 3) Default allow (public)
  rule {
    priority    = 2147483647
    action      = "allow"
    description = "Default allow (public access)"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
