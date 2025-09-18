# CronJob (no secrets, WI auth)
resource "kubernetes_cron_job_v1" "meili_backup" {
  metadata {
    name      = "${var.app_name}-backup"
    namespace = var.namespace
    labels    = local.common_labels
  }

  spec {
    schedule                      = "0 3 * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = local.common_labels
      }
      spec {
        backoff_limit = 2
        template {
          metadata {
            labels = local.common_labels
          }
          spec {
            service_account_name = kubernetes_service_account.backup.metadata[0].name
            restart_policy       = "OnFailure"

            # Make sure we can read Meili’s PVC (matches your Deployment)
            security_context { fs_group = 10001 }

            container {
              name    = "backup"
              image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:latest"
              command = ["bash", "-lc"]
              args = [
                "gsutil -m rsync -r /meili_data ${local.backup_bucket_uri}/meili/$(date +%F)/"
              ]

              resources {
                requests = {
                  cpu    = "100m"
                  memory = "256Mi"
                }
                limits = {
                  cpu    = "500m"
                  memory = "1Gi"
                }
              }

              volume_mount {
                name       = "data"
                mount_path = "/meili_data"
              }
            }

            volume {
              name = "data"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.data.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      # CronJob metadata annotations added by Autopilot
      metadata[0].annotations["autopilot.gke.io/resource-adjustment"],
      metadata[0].annotations["autopilot.gke.io/warden-version"],

      # JobTemplate PodTemplate annotations (Autopilot)
      spec[0].job_template[0].spec[0].template[0].metadata[0].annotations["autopilot.gke.io/resource-adjustment"],
      spec[0].job_template[0].spec[0].template[0].metadata[0].annotations["autopilot.gke.io/warden-version"],

      # Pod-level defaults injected by Autopilot
      spec[0].job_template[0].spec[0].template[0].spec[0].toleration,
      spec[0].job_template[0].spec[0].template[0].spec[0].security_context[0].seccomp_profile,

      # Container-level defaults (resources incl. ephemeral-storage, securityContext)
      spec[0].job_template[0].spec[0].template[0].spec[0].container[0].resources,
      spec[0].job_template[0].spec[0].template[0].spec[0].container[0].security_context,
    ]
  }
}
