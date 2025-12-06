output "bucket_url" {
  value = "http://${google_storage_bucket.static_site.name}.storage.googleapis.com"
}
