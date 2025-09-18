# CloudBloc — GCP building blocks for Saas As Code

> **MVP / Alpha**. These blocs run in a real GKE Autopilot cluster. Expect sharp edges; open issues/PRs and I’ll move fast.

CloudBloc is a suite of opinionated Terraform + Kubernetes modules ("blocs") that replace expensive SaaS with clean, self‑hosted building blocks. Ship quickly with sane defaults, then customize.

## What’s inside

* **AppBloc** — public app ingress with ManagedCert, redirects, and Cloud Armor hooks.
* **ObsBloc** — Prometheus + Grafana, Autopilot‑friendly, with minimal alerting bootstrap.
* **SearchBloc** — Meilisearch + static UI behind Nginx, PVC, and daily GCS backups.
* Infra helpers: **GKE** and **Cloud Armor** modules.

Versions (latest):

* `blocs/appbloc`: **v0.4.1**
* `blocs/obsbloc`: **v0.4.1**
* `blocs/searchbloc`: **v0.4.1**
* `modules/gke`: **v0.2.1**, `modules/cloudarmor`: \*\*v0.2.1\`

Release automation: **release‑please (manifest mode)** with per‑bloc tagging (e.g. `searchbloc-v0.4.1`).

---

## Quick start

Prereqs:

* Terraform ≥ 1.5
* `gcloud auth login` (ADC present at `~/.config/gcloud/application_default_credentials.json`)
* A GKE Autopilot cluster and a namespace (the examples create/use one)

### 1) AppBloc (public app + SSL)

`blocs/appbloc` provides an HTTPS entry with Google ManagedCertificate, optional HTTP→HTTPS redirect, and Cloud Armor integration.

```hcl
module "appbloc" {
  source = "github.com/cloudbloc-io/cloudbloc//blocs/appbloc?ref=appbloc-v0.4.1"

  namespace      = var.app_namespace
  app_name       = "cloudbloc-webapp-${var.environment}"

  image          = var.app_image
  replicas       = var.app_replicas
  container_port = var.app_port
  domains        = var.domains
  html_path      = local.html_abs_path
  enable_static_html = true

  labels         = {
    env = local.env
    }

  edge_ip_name   = var.edge_ip_name
  cloudarmor_policy = var.security_policy_name
  create_dns_zone = true
```

> See `blocs/appbloc/variables.tf` for full inputs (host rules, redirect behavior, cert SANs, etc.).

### 2) ObsBloc (Prometheus + Grafana)

`blocs/obsbloc` deploys Prometheus + Grafana with Autopilot‑friendly defaults and a minimal Alertmanager. Grafana can be made public with a Viewer role.

```hcl
module "obsbloc" {
  source = "github.com/cloudbloc-io/cloudbloc//blocs/obsbloc?ref=obsbloc-v0.4.1"

  namespace    = var.namespace
  app_name     = var.app_name
  edge_ip_name = var.edge_ip_name
  domains      = var.domains

  # searchbloc
  enable_searchbloc  = true
  searchbloc_domains = var.searchbloc_domains
  searchbloc_service = "searchbloc"

  # Existing Cloud DNS managed zone NAME (e.g., google_dns_managed_zone.cloudbloc.name)
  zone_name         = var.zone_name
  cloudarmor_policy = var.security_policy_name
  dashboards_json = {
    "k8s-overview.json"         = file("${path.module}/dashboards/k8s-overview.json")
    "prometheus-internals.json" = file("${path.module}/dashboards/prometheus-internals.json")
  }
}
```

> Dashboards are seeded via ConfigMaps; you can override with your own JSON. Check `variables.tf`/`outputs.tf` inside the bloc for the source of truth.

### 3) SearchBloc (Meilisearch + UI + backups)

`blocs/searchbloc` stands up Meilisearch with an Nginx sidecar that serves a static UI at `/` and proxies `/api/*`. Data lives on a PVC and is backed up daily to GCS via a CronJob using Workload Identity.

```hcl
module "searchbloc" {
  source = "github.com/cloudbloc-io/cloudbloc//blocs/searchbloc?ref=searchbloc-v0.4.1"

  project_id        = var.project_id
  namespace         = "obsbloc" # same namespace as obsbloc
  app_name          = "searchbloc"
  storage_size      = "5Gi"
  master_key        = var.master_key
  public_search_key = var.public_search_key
}
```

Expose it via your Ingress of choice; the Service defaults to ClusterIP. A simple `kubernetes_ingress_v1` example is in `blocs/searchbloc/README.md`.

---

## Why CloudBloc

* **Own your stack**: run core infra in your cloud, not someone else’s.
* **Sane defaults**: Autopilot‑aware equality rules and resource hints keep plans quiet.
* **GitOps‑friendly**: labels/annotations and predictable names.

---

## Architecture snapshots

**SearchBloc**

```
┌─────────────┐   /api/*    ┌──────────────┐
│   Nginx     │ ─────────▶  │ Meilisearch  │
│  (static UI)│    7700     │   :7700      │
└────┬────────┘             └────┬─────────┘
     │  / (UI)                       │ PVC (/data)
     ▼                               ▼
  ConfigMap (UI)              PersistentVolumeClaim

           ┌───────────────────────────┐
           │ CronJob → GCS (backups)  │
           └───────────────────────────┘
```

**ObsBloc (high‑level)**

```
┌──────────────┐     scrape     ┌─────────────┐
│   Grafana    │ ◀────────────▶ │ Prometheus │
└──────┬───────┘                └─────┬──────┘
       │  ingress/port                │ scrape targets
```

**AppBloc (edge)**

```
User ⇄ HTTPS ⇄ Google LB ⇄ Ingress ⇄ Service ⇄ Pod(s)
            └─ ManagedCertificate + (optional) Cloud Armor
```

---

## Status & Roadmap

**Status:** MVP/Alpha. The basics work; production hardening is ongoing.

**Near‑term:**

* SearchBloc: one‑shot restore Job example; backup retention/lifecycle notes.
* ObsBloc: default dashboards bundle + import script; optional auth for Grafana admin.
* AppBloc: more redirect/host‑rule examples; docs for Cloud Armor policies.
* CI: terraform fmt/validate, tflint on touched paths.

---

## Versioning & releases

* Conventional Commits per bloc scope, e.g. `feat(searchbloc): ...`, `fix(obsbloc): ...`.
* Monorepo **release‑please (manifest)** creates tags like `searchbloc-v0.4.1`.
* Consumers should pin to a tag in the module source `?ref=…`.

To trigger a patch release of one bloc without code changes:

```bash
git commit --allow-empty -m "fix(searchbloc): trigger patch release"
git push
```

> Tip: Set `"separate-pull-requests": true` in `.github/release-please-config.json` to get one Release PR per package and merge only what you intend to ship.

---

## Contributing

* Keep changes scoped under a bloc folder (e.g. `blocs/searchbloc/…`).
* Run `terraform fmt` and `terraform validate` before opening a PR.
* Update bloc READMEs when inputs/outputs change.

**Issue template**: include module version, Terraform version, providers, and a minimal repro.

---

## Security & Ops notes

* Never commit secrets. Pass `meili_master_key` via TF vars or a secret manager.
* Prefer TLS for public endpoints and limit ingress with Cloud Armor where applicable.
* Autopilot users: equality rules are tuned to avoid noisy plan diffs; open an issue if you see churn.

---

## License

Apache‑2.0 (see LICENSE in repo root).
