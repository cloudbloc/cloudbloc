# appbloc — GKE HTTPS app behind Global LB

Deploy a containerized web app to **Google Kubernetes Engine** behind a **Global HTTP(S) Load Balancer** with a **Google ManagedCertificate**, automatic **HTTP→HTTPS redirect**, optional **Cloud Armor**, and **Cloud DNS** records. Production-minded defaults with minimal inputs.

> Status: **v0.3.0 (Preview)** — solid for simple, stateless web apps.

## Features

* **Global HTTPS** via GCE Ingress + ManagedCertificate
* **HTTP→HTTPS redirect** (FrontendConfig)
* **Global static IP** (reused across deploys)
* **Cloud DNS** A records (either **use existing zone** or **create a new one**)
* **NEG** service with Autopilot drift ignores
* **ENV vars** (non-secret) + checksum to trigger safe rollouts
* **Probes & light resources** to keep Autopilot costs low
* **Cloud Armor** attachable via annotation

## Architecture

```
Internet → Global HTTP(S) LB → GCE Ingress (GCLB)
            ├─ ManagedCertificate (TLS)
            ├─ FrontendConfig (HTTP→HTTPS 301)
            ├─ Cloud Armor (optional)
            └─ Global Static IP
                     │
                     ▼
                 Service (NEG)
                     │
                     ▼
               Deployment (your image)
```

## Prereqs

* A GKE cluster and `kubectl` context set.
* Terraform providers: `google`, `kubernetes`. (Module also uses `kubernetes_manifest`.)
* APIs: `compute.googleapis.com`, `container.googleapis.com`, `dns.googleapis.com`.

## Quick start

### Option A — Use an existing Cloud DNS zone (recommended)

```hcl
module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/appbloc?ref=appbloc-0.3.0"

  namespace      = "appbloc"
  app_name       = "cloudbloc-webapp-prd"
  image          = "nginx:stable-alpine"
  container_port = 80
  replicas       = 2

  # Domains & IP
  edge_ip_name   = "cloudbloc-edge-ip"
  domains        = ["cloudbloc.io", "www.cloudbloc.io"]

  # Use existing zone
  create_dns_zone = false
  dns_zone_name   = "cloudbloc-io"  # existing managed zone name

  # Optional WAF
  # cloudarmor_policy = "projects/<proj>/global/securityPolicies/<policy>"

  # ENV (non-secrets)
  env = { RUNTIME = "prod" }

  # Demo HTML is OFF by default; enable only if you want it:
  # enable_static_html = true
  # html_path          = "${path.module}/examples/index.html"
}
```

### Option B — Create a new Cloud DNS zone from your apex

```hcl
module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/appbloc?ref=appbloc-0.3.0"

  namespace        = "appbloc"
  app_name         = "cloudbloc-webapp-prd"
  image            = "nginx:stable-alpine"
  container_port   = 80
  edge_ip_name     = "cloudbloc-edge-ip"
  domains          = ["example.com", "www.example.com"]

  create_dns_zone  = true  # creates a managed zone from domains[0]
}
```

Apply & verify:

```bash
terraform init
terraform apply

# Wait for certificate issuance (few minutes)
kubectl -n appbloc describe managedcertificate

# Redirect check
curl -I http://cloudbloc.io | grep -i location  # → https://cloudbloc.io/...

# HTTPS check
curl -I https://cloudbloc.io
```

## Inputs

| Name                        | Type         |          Default | Description                                                                 |
| --------------------------- | ------------ | ---------------: | --------------------------------------------------------------------------- |
| `namespace`                 | string       |                — | Target Kubernetes namespace.                                                |
| `app_name`                  | string       |                — | Base name for Deployment/Service/Ingress.                                   |
| `image`                     | string       | `"nginx:stable"` | Container image.                                                            |
| `container_port`            | number       |                — | Port exposed by the container.                                              |
| `replicas`                  | number       |              `2` | Desired replicas.                                                           |
| `labels`                    | map(string)  |             `{}` | Extra labels for resources.                                                 |
| `domains`                   | list(string) |                — | Domains for TLS & DNS records.                                              |
| `edge_ip_name`              | string       |                — | Name of the global static IP to reserve/use.                                |
| `cloudarmor_policy`         | string       |           `null` | Optional Cloud Armor policy to attach.                                      |
| `extra_ingress_annotations` | map(string)  |             `{}` | Extra annotations to merge into the Ingress.                                |
| `env`                       | map(string)  |             `{}` | Non-secret environment variables.                                           |
| `enable_static_html`        | bool         |          `false` | If `true`, mount a demo HTML page to `/usr/share/nginx/html`.               |
| `html_path`                 | string       |   `"index.html"` | Path to HTML file (used **only** when `enable_static_html = true`).         |
| `create_dns_zone`           | bool         |          `false` | If `true`, create a Cloud DNS zone from `domains[0]`.                       |
| `dns_zone_name`             | string       |           `null` | Name of an **existing** managed zone (used when `create_dns_zone = false`). |

## Outputs

| Name            | Description                                            |
| --------------- | ------------------------------------------------------ |
| `edge_ip_name`  | Global static IP resource name.                        |
| `edge_ip_addr`  | Global static IP address.                              |
| `dns_zone_name` | Active Cloud DNS zone name used (created or existing). |

## Ops notes

* **Redirect**: Ingress sets `allow-http = "true"` and points to a `FrontendConfig` that 301s to HTTPS.
* **Certs**: ManagedCertificate covers all `domains`. First issuance may take several minutes.
* **Rollouts**: Deployment includes `cloudbloc.io/env-checksum` to trigger a rollout when `env` changes.
* **NEG**: Service enables NEGs and ignores `neg-status` to avoid Autopilot diffs.

## Known limitations (v0.3.0 Preview)

* Health probes point at `/`. If your app uses `/healthz` (etc.), adjust the probes or expose a `health_path` var.
* Secrets/HPA are not included yet. Use native K8s Secrets or add an HPA as needed (planned in v0.3.x).

## Tips

* For zero-downtime single-replica rolls, consider:

  ```hcl
  strategy {
    type = "RollingUpdate"
    rolling_update { max_unavailable = 0, max_surge = "25%" }
  }
  ```
* (Optional) Add an explicit Ingress dependency:

  ```hcl
  depends_on = [kubernetes_manifest.frontend_config]
  ```
