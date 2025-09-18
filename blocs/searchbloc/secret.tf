resource "kubernetes_secret" "meili" {
  metadata {
    name      = "${var.app_name}-secrets"
    namespace = var.namespace
    labels    = local.common_labels
  }

  type = "Opaque"

  data = {
    MEILI_MASTER_KEY = base64encode(var.master_key)
  }
}
