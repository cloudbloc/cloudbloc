locals {
  namespace = var.namespace

  common_labels = merge(
    {
      app = var.app_name
    },
    var.labels
  )

  tailscale_args = concat(
    [
      "--hostname=${var.tailscale_hostname}",
    ],
    length(var.advertise_routes) > 0 ? ["--advertise-routes=${join(",", var.advertise_routes)}"] : [],
    var.accept_routes ? ["--accept-routes"] : [],
    var.advertise_exit_node ? ["--advertise-exit-node"] : [],
    var.enable_ssh ? ["--ssh"] : [],
    var.extra_args
  )
}

resource "kubernetes_namespace_v1" "this" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret_v1" "auth_key" {
  count = var.auth_key == null ? 0 : 1

  metadata {
    name      = var.auth_key_secret_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  data = {
    (var.auth_key_secret_key) = var.auth_key
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace_v1.this,
  ]
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  depends_on = [
    kubernetes_namespace_v1.this,
  ]
}

resource "kubernetes_persistent_volume_claim_v1" "state" {
  metadata {
    name      = "${var.app_name}-state"
    namespace = local.namespace
    labels    = local.common_labels
  }

  wait_until_bound = false

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.state_storage_size
      }
    }

    storage_class_name = var.state_storage_class_name
  }

  depends_on = [
    kubernetes_namespace_v1.this,
  ]
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = local.namespace
    labels    = local.common_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = local.common_labels
      }

      spec {
        service_account_name = kubernetes_service_account_v1.this.metadata[0].name
        host_network         = var.host_network
        dns_policy           = var.host_network ? "ClusterFirstWithHostNet" : "ClusterFirst"

        container {
          name  = "tailscale"
          image = var.image

          env {
            name = "TS_AUTHKEY"
            value_from {
              secret_key_ref {
                name = var.auth_key_secret_name
                key  = var.auth_key_secret_key
              }
            }
          }

          env {
            name  = "TS_STATE_DIR"
            value = "/var/lib/tailscale"
          }

          env {
            name  = "TS_USERSPACE"
            value = "false"
          }

          env {
            name  = "TS_EXTRA_ARGS"
            value = join(" ", local.tailscale_args)
          }

          security_context {
            privileged = var.privileged
            capabilities {
              add = ["NET_ADMIN", "NET_RAW"]
            }
          }

          resources {
            requests = {
              cpu    = var.resources.requests_cpu
              memory = var.resources.requests_memory
            }
            limits = {
              cpu    = var.resources.limits_cpu
              memory = var.resources.limits_memory
            }
          }

          volume_mount {
            name       = "state"
            mount_path = "/var/lib/tailscale"
          }

          volume_mount {
            name       = "tun"
            mount_path = "/dev/net/tun"
          }
        }

        volume {
          name = "state"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.state.metadata[0].name
          }
        }

        volume {
          name = "tun"
          host_path {
            path = "/dev/net/tun"
            type = "CharDevice"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.auth_key,
  ]
}
