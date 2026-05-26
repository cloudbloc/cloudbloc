# Restore Checklist

This checklist is based on the current `main` branch after `git pull --ff-only origin main` reported `Already up to date`.

Scope: analysis only. No infrastructure changes have been made.

## 1. What Terraform Manages

### Shared GCP Foundation

- `foundation/gcp/networks`
  - Creates the shared Cloud Armor policy through `modules/gcp/cloudarmor`.
  - Uses GCS remote state bucket `cloudbloc-tfstate-prd` with prefix `foundation/networks`.

- `foundation/gcp/clusters`
  - Creates a GKE cluster named `cloudbloc-gke-${environment}` through `modules/gcp/gke`.
  - Current foundation stack sets `enable_autopilot = true`.
  - Enables VPC-native networking and Workload Identity.
  - Uses GCS remote state bucket `cloudbloc-tfstate-prd` with prefix `foundation`.

### GCP Blocs

- `blocs/gcp/appbloc`
  - Kubernetes namespace, Deployment, Service, optional static HTML ConfigMap.
  - GKE `ManagedCertificate`, `FrontendConfig`, GCE Ingress.
  - Global static IP.
  - Cloud DNS managed zone when `create_dns_zone = true`, or DNS records in an existing zone when false.
  - Optional Cloud Armor policy annotation on the Ingress.

- `blocs/gcp/obsbloc`
  - Kubernetes namespace.
  - Grafana Deployment, Service, ConfigMaps for `grafana.ini`, datasource, dashboard provider, dashboards.
  - Prometheus ServiceAccount, RBAC, ConfigMaps, PVC, Deployment, Service.
  - Alertmanager ConfigMap, Deployment, Service.
  - GKE `ManagedCertificate`, `FrontendConfig`, GCE Ingress.
  - Global static IP.
  - Cloud DNS A records for ObsBloc and, when enabled, SearchBloc hostnames.
  - Optional Cloud Armor policy annotation on the Ingress.

- `blocs/gcp/searchbloc`
  - Meilisearch/Nginx Kubernetes Deployment, Service, PVC, ConfigMaps, Secret.
  - GCS backup bucket with versioning, retention, and lifecycle policy.
  - GCP service account for backups.
  - Bucket IAM binding and Workload Identity IAM binding.
  - Kubernetes ServiceAccount for backup jobs.
  - Daily Kubernetes CronJob that syncs Meilisearch data to GCS.

- `blocs/gcp/sitebloc`
  - GCS bucket configured for static website hosting.
  - Public `roles/storage.objectViewer` bucket IAM binding.

### Edge / Tiny Blocs

- `blocs/edge/appbloc`
  - Kubernetes namespace, Deployment, NodePort Service, optional static HTML ConfigMap.
  - Optional worker CronJob with optional hostPath mounts.
  - Optional in-cluster `cloudflared` Secret, ConfigMap, and Deployment.

- `blocs/edge/dropbloc`
  - Kubernetes namespace.
  - Local no-provisioner StorageClass.
  - Static hostPath PersistentVolume and bound PVC.
  - Nextcloud Helm release.
  - Optional in-cluster `cloudflared` Secret, ConfigMap, and Deployment.
  - Nextcloud cron job through the Helm chart.

## 2. Likely Manual Setup Steps

- Create or recover the GCS Terraform state bucket `cloudbloc-tfstate-prd` before running any remote-backend Terraform stack.
- Authenticate to GCP locally with Application Default Credentials.
- Enable required GCP APIs. Docs mention at least `compute.googleapis.com`, `container.googleapis.com`, and `dns.googleapis.com`; SearchBloc also needs storage and IAM APIs.
- Ensure the target GCP project exists and is accessible. Most examples default to `potent-thought-470914-t1`.
- Decide whether Cloud DNS zones are created by Terraform or are pre-existing:
  - AppBloc example sets `create_dns_zone = true`.
  - ObsBloc expects an existing Cloud DNS managed zone named `cloudbloc-io` by default.
- Ensure domain registrar nameservers point to Cloud DNS when Terraform creates a new managed zone. Terraform creates the zone and records, but registrar delegation is still outside this repo.
- Wait for GKE managed certificates to become active after DNS resolves to the load balancer IP.
- Provide ignored per-environment `*.tfvars` files for required variables such as `region` and secrets.
- For GCP Kubernetes examples, ensure the target GKE cluster already exists before applying bloc examples that use `data.google_container_cluster.gke`.
- For SearchBloc, decide whether existing Meilisearch data must be restored from a GCS backup. Terraform creates the PVC and backup job but does not provide a restore job.
- For Edge/Tiny deployments, provision the Tiny host manually:
  - Install the operating system.
  - Assign or reserve the LAN IP used by Terraform examples, currently `10.0.0.187`.
  - Install and configure Kubernetes such as k3s, MicroK8s, or equivalent.
  - Put a working kubeconfig at `~/.kube/edge` on the machine running Terraform.
  - Install or mount local storage at `/mnt/dropbloc`.
  - Prepare `/mnt/dropbloc/nextcloud-data` ownership and permissions for Nextcloud UID/GID `33`.
- For Edge/Tiny Cloudflare access:
  - Install `cloudflared` locally for tunnel setup.
  - Run `cloudflared tunnel login`.
  - Create tunnels.
  - Route DNS names to tunnels.
  - Place the generated `credentials.json` in the relevant example directory or pass another path.
- Review hard-coded edge example values before restore:
  - `examples/edge/appbloc/main.tf` contains tunnel ID `109c1cc5-0788-4761-bbe6-06cfd05c769f` and hostname `cloudbloc.io`.
  - `examples/edge/dropbloc/main.tf` contains node IP `10.0.0.187`, host path `/mnt/dropbloc/nextcloud-data`, hostname `dropbloc.cloudbloc.io`, tunnel ID `26b4d1ec-384f-477e-a404-f3d7352b45db`, and a placeholder admin password.

## 3. Missing Secrets, Files, And Env Vars

- `*.tfvars` and `*.tfvars.json` are ignored by git, so any production values are intentionally missing from the repo.
- Required Terraform variables without committed values:
  - `region` in most GCP foundation and example stacks.
  - `master_key` for `examples/gcp/searchbloc`.
- Sensitive Terraform inputs:
  - `examples/gcp/searchbloc`: `master_key`.
  - `blocs/gcp/searchbloc`: `master_key`.
  - `blocs/edge/dropbloc`: `admin_password`.
  - `blocs/edge/appbloc`: `cloudflared_credentials_json`.
  - `blocs/edge/dropbloc`: `cloudflared_credentials_file`.
- Missing local credential files:
  - `examples/edge/appbloc/credentials.json`.
  - `examples/edge/dropbloc/credentials.json`.
  - `.gitignore` explicitly excludes these files.
- Required local auth files:
  - GCP ADC at `~/.config/gcloud/application_default_credentials.json`.
  - Edge kubeconfig at `~/.kube/edge`.
- Terraform backend dependency:
  - GCS bucket `cloudbloc-tfstate-prd` must exist and be readable/writable before `terraform init -backend-config=backend/prd.conf`.
- Static content files currently used by examples:
  - `examples/gcp/appbloc/static/index.html`.
  - `examples/gcp/appbloc/static/index_future.html`.
  - `examples/edge/appbloc/static/index.html`.
  - `examples/gcp/obsbloc/dashboards/k8s-overview.json`.
  - `examples/gcp/obsbloc/dashboards/prometheus-internals.json`.
  - `blocs/gcp/searchbloc/ui/index.html`.
  - These are committed, but any customized production versions outside the repo would need to be restored separately.
- No `.env` files are committed, and no shell scripts were found to recreate local environment variables.

## 4. Host-Level Dependencies

### Machine Running Terraform

- `git`.
- `terraform` >= 1.5 for the documented GCP examples.
- `gcloud` CLI with authenticated ADC.
- Network access to:
  - GitHub module sources.
  - Terraform provider registries.
  - GCP APIs.
  - Helm chart repositories for edge DropBloc.
- For GCP stacks:
  - IAM permissions to manage GKE, Compute global addresses, Cloud DNS, Cloud Armor, GCS, IAM service accounts/bindings, and Kubernetes resources in the cluster.
- For edge stacks:
  - Access to a Kubernetes cluster through `~/.kube/edge`.
  - `kubectl` for validation and troubleshooting.
  - `cloudflared` for one-time tunnel creation and DNS routing.

### Fresh Tiny Host

- Operating system installed and reachable on the LAN.
- Stable LAN IP, currently expected by examples as `10.0.0.187`.
- Kubernetes installed and running, for example k3s or MicroK8s.
- Kubeconfig exported from the Tiny to the Terraform runner as `~/.kube/edge`.
- Container runtime and CNI installed as part of Kubernetes.
- Local storage mounted at `/mnt/dropbloc`.
- Nextcloud data directory prepared:
  - `/mnt/dropbloc/nextcloud-data`.
  - Owned by UID/GID `33:33`.
  - Permissions compatible with Nextcloud, currently documented as `770` for data and `750` for parent directory.
- Outbound internet access from the Tiny for:
  - Pulling container images.
  - Reaching Cloudflare Tunnel endpoints.
  - Downloading Helm chart images and dependencies.

## 5. Commands Needed To Rebuild On A Fresh Tiny

Adjust paths, IPs, secrets, and tunnel IDs before running these. Commands are written from the repo root unless noted.

### Prepare The Tiny Host

```bash
sudo mkdir -p /mnt/dropbloc/nextcloud-data
sudo chmod 750 /mnt/dropbloc
sudo chmod 770 /mnt/dropbloc/nextcloud-data
sudo chown -R 33:33 /mnt/dropbloc/nextcloud-data
```

Install Kubernetes on the Tiny, then copy/export its kubeconfig to the Terraform runner:

```bash
mkdir -p ~/.kube
# Copy the Tiny kubeconfig to:
# ~/.kube/edge
kubectl --kubeconfig ~/.kube/edge get nodes
```

### Prepare Cloudflare Tunnel Credentials

```bash
cloudflared tunnel login
cloudflared tunnel create appbloc-tunnel
cloudflared tunnel route dns appbloc-tunnel cloudbloc.io
cloudflared tunnel route dns appbloc-tunnel www.cloudbloc.io

cloudflared tunnel create dropbloc-tunnel
cloudflared tunnel route dns dropbloc-tunnel dropbloc.cloudbloc.io
```

Copy the generated credentials into the example directories or update Terraform variables to point elsewhere:

```bash
cp ~/.cloudflared/<appbloc-tunnel-id>.json examples/edge/appbloc/credentials.json
cp ~/.cloudflared/<dropbloc-tunnel-id>.json examples/edge/dropbloc/credentials.json
```

### Deploy Edge AppBloc

```bash
cd examples/edge/appbloc
terraform init -backend-config=backend/prd.conf
terraform plan
terraform apply
kubectl --kubeconfig ~/.kube/edge get pods -n appbloc
kubectl --kubeconfig ~/.kube/edge logs -n appbloc deploy/cloudflared
curl http://10.0.0.187:30081
```

### Deploy Edge DropBloc

Before applying, replace the committed placeholder `admin_password`, confirm `node_ip`, confirm `data_host_path`, and confirm Cloudflare tunnel values.

```bash
cd examples/edge/dropbloc
terraform init -backend-config=backend/prd.conf
terraform plan
terraform apply
kubectl --kubeconfig ~/.kube/edge get pods -n dropbloc
kubectl --kubeconfig ~/.kube/edge get cronjob -n dropbloc nextcloud-cron
curl http://10.0.0.187:30080
```

### Optional GCP Rebuild Order

```bash
cd foundation/gcp/networks
terraform init -backend-config=backend/prd.conf
terraform plan -var-file=prd.tfvars
terraform apply -var-file=prd.tfvars

cd ../clusters
terraform init -backend-config=backend/prd.conf
terraform plan -var-file=prd.tfvars
terraform apply -var-file=prd.tfvars

cd ../../../examples/gcp/appbloc
terraform init -backend-config=backend/prd.conf
terraform plan -var-file=prd.tfvars
terraform apply -var-file=prd.tfvars

cd ../obsbloc
terraform init -backend-config=backend/prd.conf
terraform plan -var-file=prd.tfvars
terraform apply -var-file=prd.tfvars

cd ../searchbloc
terraform init -backend-config=backend/prd.conf
terraform plan -var-file=prd.tfvars
terraform apply -var-file=prd.tfvars
```

## 6. TODOs To Automate Manual Steps

- Add a bootstrap script or Terraform bootstrap stack for the remote state bucket `cloudbloc-tfstate-prd`.
- Add documented `*.tfvars.example` files for every runnable stack with non-secret placeholders.
- Move hard-coded edge values out of `examples/edge/appbloc/main.tf` and `examples/edge/dropbloc/main.tf` into variables.
- Remove the committed placeholder `admin_password = "supersecurepassword"` from `examples/edge/dropbloc/main.tf`; require it via ignored tfvars or a secret manager.
- Add validation/preflight scripts for:
  - Terraform version.
  - GCP auth and active project.
  - Required GCP APIs.
  - Existence and permissions of the remote state bucket.
  - GKE cluster lookup before applying bloc examples.
  - Edge kubeconfig at `~/.kube/edge`.
  - Tiny node IP reachability.
  - Required local files such as `credentials.json`.
- Add a Tiny bootstrap script or Ansible playbook for:
  - Installing k3s or MicroK8s.
  - Exporting kubeconfig.
  - Mounting local storage.
  - Creating and permissioning `/mnt/dropbloc/nextcloud-data`.
  - Setting a static IP or documenting DHCP reservation.
- Add Terraform or scripted Cloudflare automation for tunnel creation and DNS route setup, instead of requiring `cloudflared tunnel ...` commands.
- Add secret handling through SOPS, Vault, External Secrets Operator, or Cloudflare/GCP secret managers.
- Add a SearchBloc restore job or documented one-shot restore procedure from the GCS backup bucket into the Meilisearch PVC.
- Add validation around Cloud DNS delegation when AppBloc creates a new managed zone.
- Add post-apply smoke-test scripts for:
  - Kubernetes pod readiness.
  - Cloudflare tunnel connectivity.
  - NodePort LAN access.
  - GKE managed certificate status.
  - Public HTTPS endpoint health.
- Pin `cloudflare/cloudflared:latest` to an explicit version for reproducible edge restores.
- Review and remove duplicated DropBloc Cloudflare Secret/ConfigMap resources using both unversioned and `_v1` Kubernetes providers.
- Decide whether edge examples should use local state instead of the shared GCS backend, or document why Tiny restores depend on GCP state.
