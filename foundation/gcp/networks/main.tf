module "edge_armor_shared" {
  source      = "../../../modules/gcp/cloudarmor"
  name        = "edge-armor-shared"
  description = "Cloud Armor Shared"
}
