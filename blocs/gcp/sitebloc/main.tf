resource "google_storage_bucket" "static_site" {
  name     = var.site_name
  location = var.location
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  uniform_bucket_level_access = true
}

# replaced ACL block with IAM binding compatible with uniform bucket-level access
resource "google_storage_bucket_iam_binding" "public_object_viewer" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectViewer"
  members = [
    "allUsers",
  ]
}

