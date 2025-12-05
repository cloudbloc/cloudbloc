module "gke" {
  source           = "../../../modules/gcp/gke"
  project_id       = var.project_id
  location         = var.location # ZONAL is cheaper than regional
  name             = "cloudbloc-gke-${var.environment}"
  release_channel  = "STABLE"
  enable_autopilot = true
}
