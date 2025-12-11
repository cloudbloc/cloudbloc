# sitebloc (GCP static site module)

This module creates a Google Cloud Storage bucket configured for static site hosting and grants public read access.

Usage (module call)
```hcl
module "sitebloc" {
  source    = "github.com/cloudbloc/cloudbloc//blocs/gcp/sitebloc?ref=gcp-sitebloc-0.0.1"
  site_name = "sitebloc-demo"
  location  = "US"
}
```

Or local:
```hcl
source = "../../../blocs/gcp/sitebloc"
```

Notes
- The module sets `uniform_bucket_level_access = true` and grants `roles/storage.objectViewer` to `allUsers`.
- If you run Terraform directly in the module folder, supply required variables (or run from an example that provides them).

Commands
```bash
cd examples/gcp/sitebloc
terraform init -upgrade
terraform plan -var-file=example.tfvars
```
