# Examples

Examples live under `examples/`. Each example demonstrates how to call blocs in this repo.

- examples/gcp/* — GCP-targeted examples (use `blocs/gcp/...` sources).
- examples/edge/* — edge-targeted examples (use `blocs/edge/...` sources).
- examples/edge/accessbloc — Tailscale access gateway/subnet-router example for a Tiny or homelab node.

Run an example:
```bash
cd examples/gcp/sitebloc
terraform init -upgrade
terraform plan -var-file=example.tfvars
```
