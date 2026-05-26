# AppBloc Restore Requirements

This document records exactly what is needed to reproduce the Edge AppBloc deployment from this repository.

Current checkout status:

- Branch `main` was pulled and was already up to date.
- No local Terraform state directory or state file was found under `examples/edge/appbloc`.
- `examples/edge/appbloc/credentials.json` is missing in this checkout.
- `/home/yprk/.kube/edge` is missing on this machine.
- Because the kubeconfig and Terraform state access are not present locally, this document is repo-derived. It does not prove what is currently live on the Tiny.

## Terraform Entry Point

Use this Terraform root:

```bash
examples/edge/appbloc
```

Backend:

```hcl
terraform {
  backend "gcs" {
    prefix = "edge-appbloc"
  }
}
```

Backend config:

```hcl
bucket = "cloudbloc-tfstate-prd"
```

Provider config:

```hcl
provider "kubernetes" {
  config_path = "~/.kube/edge"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/edge"
  }
}
```

## Exact Committed AppBloc Inputs

These values come from `examples/edge/appbloc/main.tf` and `examples/edge/appbloc/variables.tf`.

Defaults:

```hcl
environment   = "prd"
app_namespace = "appbloc"
app_image     = "nginx:stable"
app_port      = 80
app_replicas  = 1
html_path     = "index.html"
node_port     = 30081
domains       = ["cloudbloc.io", "www.cloudbloc.io"]
```

Computed locals:

```hcl
env           = var.environment
html_abs_path = "${path.root}/static/${var.html_path}"
```

Effective module inputs:

```hcl
namespace      = "appbloc"
app_name       = "cloudbloc-webapp-prd"
image          = "nginx:stable"
container_port = 80
replicas       = 1

labels = {
  env = "prd"
}

enable_static_html = true
html_path          = "${path.root}/static/index.html"

node_port = 30081

enable_cloudflared           = true
cloudflared_tunnel_id        = "109c1cc5-0788-4761-bbe6-06cfd05c769f"
cloudflared_hostname         = "cloudbloc.io"
cloudflared_credentials_json = file("${path.module}/credentials.json")
```

Module source:

```hcl
source = "../../../blocs/edge/appbloc"
```

The committed static HTML file is:

```bash
examples/edge/appbloc/static/index.html
```

## Resources Terraform Creates

The Edge AppBloc module creates:

- Kubernetes namespace: `appbloc`.
- Optional ConfigMap `web-html` containing `index.html`.
- Kubernetes Deployment: `cloudbloc-webapp-prd`.
- Kubernetes NodePort Service: `cloudbloc-webapp-prd-svc`.
- NodePort: `30081`.
- Optional worker CronJob if `enable_worker = true`; the current example does not enable it.
- Optional Cloudflare tunnel resources because `enable_cloudflared = true`:
  - Secret `cloudflared-credentials`.
  - ConfigMap `cloudflared-config`.
  - Deployment `cloudflared`.

The `cloudflared` config routes:

- `cloudbloc.io` to the AppBloc service.
- `www.cloudbloc.io` to the AppBloc service.
- all other requests to `http_status:404`.

## Required Host State On The Tiny

The Tiny must have:

- Kubernetes installed and running.
- A kubeconfig for the cluster copied to the Terraform runner at `~/.kube/edge`.
- A node reachable on the LAN for NodePort traffic.
- NodePort `30081` available.
- Outbound internet access to pull:
  - `nginx:stable`.
  - `cloudflare/cloudflared:latest`.

Unlike DropBloc, AppBloc does not require a persistent hostPath data directory for the current example.

## Required Local Files

The machine running Terraform needs:

```bash
~/.kube/edge
examples/edge/appbloc/credentials.json
examples/edge/appbloc/static/index.html
```

Current local check:

- `~/.kube/edge`: missing.
- `examples/edge/appbloc/credentials.json`: missing.
- `examples/edge/appbloc/static/index.html`: present and committed.

`credentials.json` is intentionally ignored by git:

```gitignore
examples/edge/appbloc/credentials.json
```

## Required External State

### Terraform State

Terraform expects remote state in:

```text
gs://cloudbloc-tfstate-prd/edge-appbloc
```

To reproduce from existing state, the runner needs GCP auth with read/write access to the `cloudbloc-tfstate-prd` bucket.

To reproduce from scratch, the bucket must exist before `terraform init`.

### Cloudflare Tunnel

The committed tunnel ID is:

```text
109c1cc5-0788-4761-bbe6-06cfd05c769f
```

The public hostnames are:

```text
cloudbloc.io
www.cloudbloc.io
```

To reproduce exactly, Cloudflare must contain:

- A tunnel with ID `109c1cc5-0788-4761-bbe6-06cfd05c769f`.
- DNS routes for `cloudbloc.io` and `www.cloudbloc.io` to that tunnel.
- The matching tunnel credentials JSON at `examples/edge/appbloc/credentials.json`.

If recreating instead of restoring the same tunnel, create a new tunnel and update `cloudflared_tunnel_id` plus `credentials.json`.

## Rebuild Commands

Verify kubeconfig from the Terraform runner:

```bash
kubectl --kubeconfig ~/.kube/edge get nodes
```

Verify the Cloudflare credential file exists:

```bash
test -f examples/edge/appbloc/credentials.json
```

Verify the static site file exists:

```bash
test -f examples/edge/appbloc/static/index.html
```

Deploy:

```bash
cd examples/edge/appbloc
terraform init -backend-config=backend/prd.conf
terraform plan
terraform apply
```

Validate:

```bash
kubectl --kubeconfig ~/.kube/edge get all -n appbloc
kubectl --kubeconfig ~/.kube/edge get configmap -n appbloc web-html
kubectl --kubeconfig ~/.kube/edge get secret -n appbloc cloudflared-credentials
kubectl --kubeconfig ~/.kube/edge logs -n appbloc deploy/cloudflared
curl http://<tiny-lan-ip>:30081
curl https://cloudbloc.io
curl https://www.cloudbloc.io
```

Expected Terraform outputs:

```text
service_name       = cloudbloc-webapp-prd-svc
service_namespace  = appbloc
service_node_port  = 30081
```

## Live-State Audit Commands

Once `~/.kube/edge`, `credentials.json`, and GCP backend access are available, use these commands to compare actual deployed state with Terraform:

```bash
cd examples/edge/appbloc
terraform init -backend-config=backend/prd.conf
terraform state list
terraform plan
```

```bash
kubectl --kubeconfig ~/.kube/edge get all -n appbloc
kubectl --kubeconfig ~/.kube/edge get service -n appbloc cloudbloc-webapp-prd-svc -o wide
kubectl --kubeconfig ~/.kube/edge get configmap -n appbloc web-html -o yaml
kubectl --kubeconfig ~/.kube/edge get secret -n appbloc cloudflared-credentials
kubectl --kubeconfig ~/.kube/edge get deployment -n appbloc cloudbloc-webapp-prd -o yaml
kubectl --kubeconfig ~/.kube/edge get deployment -n appbloc cloudflared -o yaml
kubectl --kubeconfig ~/.kube/edge logs -n appbloc deploy/cloudflared
```

Cloudflare-side checks:

```bash
cloudflared tunnel list
cloudflared tunnel route dns list
```

## Not Fully Reproducible From The Repo Alone

These are required but not reproducible from committed Terraform alone:

- Tiny OS install.
- Kubernetes install on the Tiny.
- The actual Tiny LAN IP used for `curl http://<tiny-lan-ip>:30081`.
- Kubeconfig at `~/.kube/edge`.
- Cloudflare tunnel credentials JSON.
- Cloudflare account state and DNS routes for `cloudbloc.io` and `www.cloudbloc.io`.
- GCS Terraform backend bucket and remote state access.

## Automation TODOs

- Move hard-coded Cloudflare values from `examples/edge/appbloc/main.tf` into variables and an `appbloc.tfvars.example`.
- Add a Tiny bootstrap script for Kubernetes install and NodePort reachability validation.
- Add a preflight script that checks:
  - `~/.kube/edge` exists and can reach the cluster.
  - `credentials.json` exists.
  - `static/index.html` exists.
  - NodePort `30081` is available.
  - Terraform can access `gs://cloudbloc-tfstate-prd/edge-appbloc`.
- Automate Cloudflare tunnel creation and DNS route creation, or document how to import an existing tunnel.
- Pin `cloudflare/cloudflared:latest` to a fixed version.
- Add post-apply smoke tests for LAN NodePort and both public HTTPS hostnames.
- Decide whether Edge AppBloc should use local state instead of the shared GCS backend, or document why reproducing the Tiny deployment depends on GCP state.
