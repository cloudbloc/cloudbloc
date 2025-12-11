# sitebloc (example)

This example demonstrates how to host a static site using the sitebloc module.

Important
- The example calls the module using the GitHub-style source by default:
  `source = "github.com/cloudbloc/cloudbloc//blocs/gcp/sitebloc?ref=gcp-sitebloc-0.0.1"`

To switch to a local module during development:
```hcl
# Use the local module instead of the GitHub URL
# source = "../../../blocs/gcp/sitebloc"
# or for edge:
# source = "../../../blocs/edge/sitebloc"
```

Commands
```bash
cd examples/gcp/sitebloc
terraform init -upgrade
terraform plan -var-file=example.tfvars
```
