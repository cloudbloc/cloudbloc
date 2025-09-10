module "searchbloc" {
  source = "../../../blocs/searchbloc"

  namespace           = "obsbloc" # same namespace as obsbloc
  app_name            = "searchbloc"
  master_key          = var.master_key
  storage_size        = "5Gi"
}
