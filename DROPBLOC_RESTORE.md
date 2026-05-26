# DropBloc Restore Requirements

This document records exactly what is needed to reproduce the DropBloc deployment from this repository.

Current checkout status:

- Branch `main` was pulled and was already up to date.
- No local Terraform state directory or state file was found under `examples/edge/dropbloc`.
- `examples/edge/dropbloc/credentials.json` is missing in this checkout.
- `/home/yprk/.kube/edge` is missing on this machine.
- Because the kubeconfig and Terraform state access are not present locally, this document is repo-derived. It does not prove what is currently live on the Tiny.

## Terraform Entry Point

Use this Terraform root:

```bash
examples/edge/dropbloc
```

Backend:

```hcl
terraform {
  backend "gcs" {
    prefix = "edge-dropbloc"
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

## Exact Committed DropBloc Inputs

These values are currently hard-coded in `examples/edge/dropbloc/main.tf`:

```hcl
namespace      = "dropbloc"
node_ip        = "10.0.0.187"
data_host_path = "/mnt/dropbloc/nextcloud-data"
data_size      = "800Gi"

nextcloud_hostname           = "dropbloc.cloudbloc.io"
nextcloud_canonical_host     = "10.0.0.187:30080"
nextcloud_canonical_protocol = "http"

admin_username = "admin"
admin_password = "supersecurepassword"

service_node_port = 30080

enable_cloudflared           = true
cloudflared_credentials_file = abspath("${path.module}/credentials.json")
cloudflared_tunnel_id        = "26b4d1ec-384f-477e-a404-f3d7352b45db"

nextcloud_files_scan_paths = [
  "yprk/files/yt",
  "donggu/files/yt",
]

nextcloud_cron_schedule = "*/5 * * * *"
```

Module source:

```hcl
source = "../../../blocs/edge/dropbloc"
```

## Resources Terraform Creates

The DropBloc module creates:

- Kubernetes namespace: `dropbloc`.
- Kubernetes StorageClass: default `nextcloud-local-storage`.
- Kubernetes PersistentVolume: `nextcloud-data-pv`.
- Kubernetes PersistentVolumeClaim: `nextcloud-data-pvc` in namespace `dropbloc`.
- Helm release: `nextcloud` in namespace `dropbloc`.
- Nextcloud service exposed through NodePort `30080`.
- Nextcloud internal database via the Helm chart.
- Nextcloud cron job via the Helm chart, scheduled `*/5 * * * *`.
- Optional Cloudflare tunnel resources because `enable_cloudflared = true`:
  - Secret `cloudflared-credentials`.
  - ConfigMap `cloudflared-config`.
  - Secret `cloudflared-credentials-v1`.
  - ConfigMap `cloudflared-config-v1`.
  - Deployment `cloudflared`.

Note: the module currently defines both unversioned and `_v1` Cloudflare Secret/ConfigMap resources, but the Deployment mounts the `_v1` versions.

## Required Host State On The Tiny

The Tiny must have:

- LAN IP `10.0.0.187`, or the Terraform input must be changed.
- Kubernetes installed and running.
- A kubeconfig for the cluster copied to the Terraform runner at `~/.kube/edge`.
- Local storage mounted so this path exists and persists:

```bash
/mnt/dropbloc/nextcloud-data
```

Prepare the storage path on the Tiny:

```bash
sudo mkdir -p /mnt/dropbloc/nextcloud-data
sudo chmod 750 /mnt/dropbloc
sudo chmod 770 /mnt/dropbloc/nextcloud-data
sudo chown -R 33:33 /mnt/dropbloc/nextcloud-data
```

The UID/GID `33:33` is required because the Nextcloud chart is configured to run as that user/group.

## Required Local Files

The machine running Terraform needs:

```bash
~/.kube/edge
examples/edge/dropbloc/credentials.json
```

Current local check:

- `~/.kube/edge`: missing.
- `examples/edge/dropbloc/credentials.json`: missing.

`credentials.json` is intentionally ignored by git:

```gitignore
examples/edge/dropbloc/credentials.json
```

## Required External State

### Terraform State

Terraform expects remote state in:

```text
gs://cloudbloc-tfstate-prd/edge-dropbloc
```

To reproduce from existing state, the runner needs GCP auth with read/write access to the `cloudbloc-tfstate-prd` bucket.

To reproduce from scratch, the bucket must exist before `terraform init`.

### Cloudflare Tunnel

The committed tunnel ID is:

```text
26b4d1ec-384f-477e-a404-f3d7352b45db
```

The public hostname is:

```text
dropbloc.cloudbloc.io
```

To reproduce exactly, Cloudflare must contain:

- A tunnel with ID `26b4d1ec-384f-477e-a404-f3d7352b45db`.
- DNS route for `dropbloc.cloudbloc.io` to that tunnel.
- The matching tunnel credentials JSON at `examples/edge/dropbloc/credentials.json`.

If recreating instead of restoring the same tunnel, create a new tunnel and update `cloudflared_tunnel_id` plus `credentials.json`.

## Rebuild Commands

Run host prep on the Tiny first:

```bash
sudo mkdir -p /mnt/dropbloc/nextcloud-data
sudo chmod 750 /mnt/dropbloc
sudo chmod 770 /mnt/dropbloc/nextcloud-data
sudo chown -R 33:33 /mnt/dropbloc/nextcloud-data
```

Verify kubeconfig from the Terraform runner:

```bash
kubectl --kubeconfig ~/.kube/edge get nodes
```

Verify the Cloudflare credential file exists:

```bash
test -f examples/edge/dropbloc/credentials.json
```

Deploy:

```bash
cd examples/edge/dropbloc
terraform init -backend-config=backend/prd.conf
terraform plan
terraform apply
```

Validate:

```bash
kubectl --kubeconfig ~/.kube/edge get all -n dropbloc
kubectl --kubeconfig ~/.kube/edge get pv nextcloud-data-pv
kubectl --kubeconfig ~/.kube/edge get pvc -n dropbloc nextcloud-data-pvc
kubectl --kubeconfig ~/.kube/edge get storageclass nextcloud-local-storage
kubectl --kubeconfig ~/.kube/edge get cronjob -n dropbloc nextcloud-cron
kubectl --kubeconfig ~/.kube/edge logs -n dropbloc deploy/cloudflared
curl http://10.0.0.187:30080
```

Expected outputs:

```text
nextcloud_lan_url    = http://10.0.0.187:30080
nextcloud_public_url = dropbloc.cloudbloc.io
```

## Live-State Audit Commands

Once `~/.kube/edge`, `credentials.json`, and GCP backend access are available, use these commands to compare actual deployed state with Terraform:

```bash
cd examples/edge/dropbloc
terraform init -backend-config=backend/prd.conf
terraform state list
terraform plan
```

```bash
kubectl --kubeconfig ~/.kube/edge get all -n dropbloc
kubectl --kubeconfig ~/.kube/edge get pv,pvc -A
kubectl --kubeconfig ~/.kube/edge get storageclass
kubectl --kubeconfig ~/.kube/edge get secret,configmap -n dropbloc
kubectl --kubeconfig ~/.kube/edge get cronjob,jobs -n dropbloc
kubectl --kubeconfig ~/.kube/edge describe pv nextcloud-data-pv
kubectl --kubeconfig ~/.kube/edge describe pvc -n dropbloc nextcloud-data-pvc
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
- Stable LAN IP assignment for `10.0.0.187`.
- The mounted disk/filesystem behind `/mnt/dropbloc`.
- Existing Nextcloud user files in `/mnt/dropbloc/nextcloud-data`.
- Kubeconfig at `~/.kube/edge`.
- Cloudflare tunnel credentials JSON.
- Cloudflare account state and DNS route for `dropbloc.cloudbloc.io`.
- GCS Terraform backend bucket and remote state access.

## Automation TODOs

- Move all hard-coded values from `examples/edge/dropbloc/main.tf` into variables and a `dropbloc.tfvars.example`.
- Remove the committed placeholder `admin_password = "supersecurepassword"` and require it through ignored tfvars or a secret manager.
- Add a Tiny bootstrap script for Kubernetes install, static IP verification, storage mount, and directory permissions.
- Add a preflight script that checks:
  - `~/.kube/edge` exists and can reach the cluster.
  - `credentials.json` exists.
  - `10.0.0.187` is reachable.
  - `/mnt/dropbloc/nextcloud-data` exists on the Tiny and is owned by `33:33`.
  - Terraform can access `gs://cloudbloc-tfstate-prd/edge-dropbloc`.
- Automate Cloudflare tunnel creation and DNS route creation, or document how to import an existing tunnel.
- Pin `cloudflare/cloudflared:latest` to a fixed version.
- Remove duplicate unversioned Cloudflare Secret/ConfigMap resources if they are not used.
- Add a backup and restore procedure for `/mnt/dropbloc/nextcloud-data`.
