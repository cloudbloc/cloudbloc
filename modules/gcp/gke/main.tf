# Autopilot cluster (created only when enable_autopilot = true)
resource "google_container_cluster" "autopilot" {
  count    = var.enable_autopilot ? 1 : 0
  name     = var.name
  location = var.location

  enable_autopilot = true

  release_channel { channel = var.release_channel }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Standard cluster (created only when enable_autopilot = false)
resource "google_container_cluster" "standard" {
  count    = var.enable_autopilot ? 0 : 1
  name     = var.name
  location = var.location

  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel { channel = var.release_channel }

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  lifecycle {
    ignore_changes = [node_pool]
  }
}

# Node pool only for Standard
resource "google_container_node_pool" "default" {
  count    = var.enable_autopilot ? 0 : 1
  name     = "${var.name}-pool"
  location = var.location
  cluster  = google_container_cluster.standard[0].name

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  node_config {
    machine_type = var.machine_type
    spot         = var.spot
    disk_size_gb = var.disk_size_gb
    image_type   = "COS_CONTAINERD"

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    labels   = { cluster = var.name }
    metadata = { disable-legacy-endpoints = "true" }
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }
}
