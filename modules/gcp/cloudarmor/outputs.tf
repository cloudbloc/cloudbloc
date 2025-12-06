output "policy_name" {
  value       = google_compute_security_policy.this.name
  description = "Security policy name (use in Ingress annotation)."
}

output "policy_id" {
  value       = google_compute_security_policy.this.id
  description = "Security policy ID."
}

output "ingress_annotation" {
  value       = { "gcp.cloud.google.com/security-policy" = google_compute_security_policy.this.name }
  description = "Key/value you can merge into Ingress annotations."
}
