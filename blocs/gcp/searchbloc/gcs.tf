resource "google_storage_bucket" "backups" {
  project                     = var.project_id
  name                        = var.backup_bucket_name
  location                    = var.backup_bucket_location
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning { enabled = true } # protect against accidental overwrite

  lifecycle_rule {
    condition { age = 30 } # keep 30 days of backups
    action { type = "Delete" }
  }

  retention_policy {
    retention_period = 604800 # 7 days (seconds)
  }
}
