module "searchbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/gcp/searchbloc?ref=searchbloc-0.4.2"
  # source = "../../../blocs/searchbloc"

  project_id        = var.project_id
  namespace         = "obsbloc" # same namespace as obsbloc
  app_name          = "searchbloc"
  storage_size      = "5Gi"
  master_key        = var.master_key
  public_search_key = var.public_search_key
}
