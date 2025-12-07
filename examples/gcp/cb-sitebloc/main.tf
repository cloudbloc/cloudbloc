module "sitebloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/gcp/sitebloc?ref=gcp-sitebloc-0.0.1"
  # source         = "../../../blocs/gcp/sitebloc"
  site_name = var.site_name
  location  = var.location
}
