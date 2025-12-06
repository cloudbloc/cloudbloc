module "sitebloc" {
  # source = "github.com/cloudbloc/cloudbloc//blocs/gcp/sitebloc?ref=sitebloc-0.4.2"
  source         = "../../../blocs/gcp/sitebloc"
  site_name = "${var.site_name}"
  location    = var.location
}