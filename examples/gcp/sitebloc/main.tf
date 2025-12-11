module "sitebloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/gcp/sitebloc?ref=gcp-sitebloc-v0.0.2"
  # source         = "../../../blocs/gcp/sitebloc"
  site_name = var.site_name
  location  = var.location
}
