# Reserve a global static IP
resource "google_compute_global_address" "app_edge_ip" {
  name = var.edge_ip_name

}

# DNS managed zone based on the first domain
resource "google_dns_managed_zone" "zone" {
  name        = replace(var.domains[0], ".", "-") # e.g. "cloudbloc-io"
  dns_name    = "${var.domains[0]}."              # e.g. "cloudbloc.io."
  description = "Zone for ${var.domains[0]}"
}

# A records for every domain in var.domains
resource "google_dns_record_set" "a_records" {
  for_each     = toset(var.domains)
  name         = "${each.value}." # e.g. "cloudbloc.io.", "www.cloudbloc.io."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.zone.name
  rrdatas      = [google_compute_global_address.app_edge_ip.address]
}
