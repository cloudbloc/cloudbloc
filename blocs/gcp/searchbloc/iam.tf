resource "google_service_account" "backups" {
  project      = var.project_id
  account_id   = "backups-writer"
  display_name = "SearchBloc backups writer"
}

resource "google_storage_bucket_iam_member" "admin" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.backups.email}"
}

resource "kubernetes_service_account" "backup" {
  metadata {
    name      = "${var.app_name}-backup"
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.backups.email
    }
    labels = local.common_labels
  }
}

# Allow KSA to impersonate GCP SA
resource "google_service_account_iam_member" "wi_bind" {
  service_account_id = google_service_account.backups.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${kubernetes_service_account.backup.metadata[0].name}]"
}
