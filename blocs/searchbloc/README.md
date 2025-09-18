# SearchBloc (Meilisearch + UI)

Opinionated, production‑ready Meilisearch on Kubernetes with a tiny Nginx edge for a bundled static UI and a first‑class backup story. Defaults are tuned for GKE Autopilot but work on standard K8s too.

> **Tagline:** lightning‑fast search, self‑hosted, GitOps‑friendly.

---

## What you get

* **Meilisearch** Deployment + Service (ClusterIP by default)
* **Nginx** sidecar as a light reverse proxy

  * `/` → static SearchBloc UI (ConfigMap-mounted)
  * `/api/*` → Meilisearch HTTP
* **Persistent storage** (PVC)
* **Daily backups** to **GCS** via Kubernetes **CronJob** (tar + timestamp to `gs://<bucket>`)
* **Workload identity**/**SA** for safe GCS access (GCP)
* Opinionated defaults compatible with **GKE Autopilot** (resource hints, seccomp, non‑root, etc.)
* Labels/annotations wired for GitOps and diff‑friendly equality rules (CronJob templating quirks handled)

---

## Architecture

```
┌─────────────┐        /api/*       ┌──────────────┐
│  Nginx      │  ───────────────▶  │  Meilisearch │
│  (static UI)│        7700        │   :7700       │
└─────┬───────┘                     └──────┬───────┘
      │ / (UI)                               │ PVC (/data)
      ▼                                       ▼
 ConfigMap (UI)                          PersistentVolumeClaim

                 ┌───────────────────────────────┐
                 │   CronJob (daily backups)     │
                 │  gs://<backup_bucket_name>    │
                 └───────────────────────────────┘
```

---

## Requirements

* **Terraform** ≥ 1.5
* Providers:

  * `kubernetes` ≥ 2.25 (configured against your cluster)
  * `google` (only if you let the module create GCP resources)
* A **namespace** in your cluster
* A **GCS bucket** for backups (module can create & wire IAM if desired)

> **GKE Autopilot:** module adds Autopilot‑injected defaults to `lifecycle.ignore_changes` for Deployments and CronJobs to keep plans clean.

---

## Quick start

```hcl
module "searchbloc" {
  source = "github.com/cloudbloc-io/cloudbloc//blocs/searchbloc?ref=searchbloc-v0.3.4"

  namespace = "search"
  app_name  = "searchbloc"

  # Storage & backup
  data_rev              = 1                        # bump to rotate PVC name safely
  storage_size          = "20Gi"                  # PVC size
  backup_bucket_name    = "searchbloc-backups"    # no gs:// prefix
  backup_bucket_location = "US"                   # e.g., NORTHAMERICA-NORTHEAST1

  # Meilisearch
  meili_master_key      = var.meili_master_key     # recommend via TF var/secret
  replicas              = 1

  # Optional labels
  labels = { env = "dev" }
}
```

Expose it (examples):

* **ClusterIP** + internal clients (default)
* **Ingress** (GKE Ingress, NGINX ingress) in your overlay:

```hcl
resource "kubernetes_ingress_v1" "search" {
  metadata { name = "searchbloc" namespace = module.searchbloc.namespace }
  spec {
    rule {
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend { service { name = module.searchbloc.service_name port { number = 80 } } }
        }
      }
    }
  }
}
```

---

## Inputs

> **Note:** The exact list below mirrors the current module and may evolve; check `variables.tf` in the repo for the source of truth.

| Name                     | Type        | Default                      | Description                                               |
| ------------------------ | ----------- | ---------------------------- | --------------------------------------------------------- |
| `namespace`              | string      | n/a                          | Namespace to deploy into.                                 |
| `app_name`               | string      | `"searchbloc"`               | Base name for resources.                                  |
| `labels`                 | map(string) | `{}`                         | Extra labels merged into all resources.                   |
| `replicas`               | number      | `1`                          | Meilisearch replica count.                                |
| `storage_size`           | string      | `"20Gi"`                     | PVC size for Meilisearch data.                            |
| `data_rev`               | number      | `1`                          | Bump to force a new PVC name (safe rotation).             |
| `meili_master_key`       | string      | n/a                          | **Required**. Admin key for Meilisearch. Supply securely. |
| `backup_bucket_name`     | string      | `"searchbloc-backup-bucket"` | GCS bucket name (no `gs://`).                             |
| `backup_bucket_location` | string      | `"US"`                       | GCS bucket location/region.                               |
| `backup_schedule`        | string      | `"0 3 * * *"`                | Cron schedule (UTC) for daily backup.                     |
| `resources`              | object      | reasonable defaults          | CPU/memory requests & limits for Autopilot friendliness.  |

Common advanced knobs (if enabled in the module):

* Service type/ports, node selectors/tolerations, Pod securityContext, image tags, equality‑rule toggles for CronJobs, backup retention count.

---

## Outputs

| Name                    | Description                                  |
| ----------------------- | -------------------------------------------- |
| `namespace`             | The namespace used.                          |
| `service_name`          | K8s Service name exposing Nginx/Meilisearch. |
| `deployment_name`       | Meilisearch Deployment name.                 |
| `pvc_name`              | Name of the PersistentVolumeClaim.           |
| `backup_bucket_uri`     | `gs://…` URI computed for the bucket.        |
| `backup_cronjob_name`   | Name of the CronJob handling backups.        |
| `service_account_email` | GCP SA used for backups (if created).        |

> See `outputs.tf` for the definitive list.

---

## Backups (design)

* **What:** `tar.gz` of `/data` with a timestamped object key
* **Where:** `gs://<backup_bucket_name>/<app_name>/<YYYY/MM/DD>/…`
* **Auth:** Workload Identity → GCP SA with minimal `roles/storage.objectAdmin` on the bucket
* **Restore:** `kubectl cp` or a one‑shot Job to download & unpack into the PVC (restore Job example coming soon)

---

## Security

* Non‑root, read‑only rootfs where possible
* Seccomp (runtime/default) and drop‑capabilities
* Network is private by default (ClusterIP). Expose only through your Ingress with TLS.
* **Do not** hard‑code `meili_master_key` in VCS. Pass via TF var files or external secret managers (ESO, SOPS + CI, etc.).

---

## Observability

* Basic readiness/liveness probes
* Prometheus scrape annotations (optional) if you have a cluster‑wide discovery

---

## Versioning & releases (monorepo‑friendly)

We use **Conventional Commits** + **release‑please** in **manifest** mode so each bloc gets its own version & tag.

### Commit message rules

* **feat(searchbloc):** new functionality → **minor** bump
* **fix(searchbloc):** bug fix / default tweaks → **patch** bump
* **perf(searchbloc):** performance improvement → **patch**
* **refactor/docs/chore(ci)** normally **no release** unless `!` or `release‑please` config says otherwise

### Normal release flow (recommended)

1. Make your changes in `blocs/searchbloc/…`.
2. Commit using a conventional scope:

   ```bash
   git add -A
   git commit -m "fix(searchbloc): correct pvc lifecycle ignore rules"
   git push origin <branch>
   ```
3. Wait for the **release‑please** GitHub Action to open a **Release PR** for SearchBloc.
4. Merge the Release PR → Action creates **tag** `searchbloc-vX.Y.Z` and **GitHub Release** with changelog.

> Ensure the repo has a `release-please-config.json` + `manifest.json` mapping `blocs/searchbloc` → package name `searchbloc` and tag pattern `searchbloc-v${version}`.

### For a quick patch without code changes (allowed empty)

```bash
git commit --allow-empty -m "fix(searchbloc): trigger patch release"
git push
# release-please will generate/advance the Release PR for searchbloc
```

### Manual override (if automation is misconfigured)

```bash
# choose the next version consciously
export VERSION=0.3.4

git tag -a searchbloc-v${VERSION} -m "release: searchbloc v${VERSION}"
git push origin searchbloc-v${VERSION}
```

Consumers can pin this version via:

```hcl
source = "github.com/cloudbloc-io/cloudbloc//blocs/searchbloc?ref=searchbloc-v0.3.4"
```

---

## Upgrading safely

* **Data changes**: bump `data_rev` to rotate PVC name (keeps old PVC around for rollback)
* **Config only**: Deployment restarts are rolling (or Recreate on Autopilot as configured)
* **Downgrades**: pin an older tag and re‑apply; PVC remains. For schema‑breaking Meilisearch versions, restore from backup if needed.

---

## Restore example (coming soon)

Planned: a one‑shot Kubernetes Job spec you can apply with a chosen backup object path to hydrate the PVC.

---

## FAQ

**Q: Can I run this on non‑GKE clusters?**
Yes. Skip the GCP SA bits and wire your own object storage or mount a backup volume. The CronJob container only needs credentials to write to your store.

**Q: Can I expose it publicly?**
Yes, but always front with TLS and an auth layer if you don’t want a public search API. Nginx is ready for an external Ingress.

**Q: What about multi‑tenancy?**
Use separate namespaces/apps or index prefixes. Backups are bucket‑key partitioned by `app_name`.

---

## Local development

* Kind/minikube works; set smaller resources
* Provide `MEILI_MASTER_KEY` via TF var or ad‑hoc Secret

---

## Contributing

* Run `terraform fmt`/`validate`
* Keep equality rules/diff suppression tidy for Autopilot noise
* Add tests/examples under `examples/`
* Write Conventional Commits with the **(searchbloc)** scope

---

## License

Apache‑2.0 (see root of repo)
