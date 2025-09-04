output "name" {
  description = "Cluster name"
  value = try(
    google_container_cluster.autopilot[0].name,
    google_container_cluster.standard[0].name
  )
}

output "endpoint" {
  description = "API endpoint"
  value = "https://${try(
    google_container_cluster.autopilot[0].endpoint,
    google_container_cluster.standard[0].endpoint
  )}"
}

output "ca_certificate" {
  description = "Cluster CA cert"
  value = try(
    google_container_cluster.autopilot[0].master_auth[0].cluster_ca_certificate,
    google_container_cluster.standard[0].master_auth[0].cluster_ca_certificate
  )
  sensitive = true
}
