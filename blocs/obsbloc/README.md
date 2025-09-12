# ObsBloc (Grafana + Prometheus + Alertmanager) for GKE

A tiny, production-lean **observability bloc** that exposes a **public, read-only Grafana** at your domain, backed by a **lightweight in-cluster Prometheus** and a silent **Alertmanager**. Built for **GKE + GCE Ingress** with **ManagedCertificate** and **HTTP→HTTPS redirect**.

---

## What gets created

* **Grafana**

  * Anonymous **Viewer** access (no edits, no login)
  * Pre-provisioned **Prometheus** datasource
  * Dashboard **provider** + a default dashboard so the first screen isn’t empty

* **Prometheus**

  * 1 replica, with **time + size-based retention** (`3d` and `8GB` by default)
  * Data persisted to a **PVC** (resizes in place if your StorageClass allows it)
  * Pod discovery by annotation (minimal RBAC)

* **Alertmanager**

  * 1 replica, default config with a **no-op receiver**
  * Alerts flow from Prometheus → Alertmanager, but **no external notifications** are sent until you add a real receiver (Slack, email, PagerDuty)

* **Networking**

  * **GCE Ingress** (NEG) with **ManagedCertificate**
  * **FrontendConfig** to 301 redirect **HTTP → HTTPS**
  * **Global static IP**
  * **DNS A records** in your **existing** Cloud DNS zone (`zone_name`)

---

## Requirements

* A **GKE** cluster with the **GCE Ingress** controller (standard on GKE)
* A **Cloud DNS** managed zone for your parent domain already exists (e.g., `cloudbloc.io`)
* `terraform`, `kubectl`, `gcloud` authenticated to your project and cluster

---

## Usage

```hcl
module "obsbloc" {
  source       = "./modules/obsbloc"

  # Names
  namespace    = "obsbloc"
  app_name     = "obsbloc"

  # Networking / DNS
  edge_ip_name = "obsbloc-edge-ip"
  domains      = ["obsbloc.cloudbloc.io", "www.obsbloc.cloudbloc.io"]
  zone_name    = "cloudbloc-io" # existing Cloud DNS managed zone NAME

  # Prometheus
  prometheus_retention       = "3d"
  prometheus_retention_size  = "8GB"
  prometheus_storage_size    = "10Gi"
  prometheus_storage_class   = "pd-standard"
}
```

Apply:

```bash
terraform init
terraform apply
```

> **Heads up on TLS**: Google **ManagedCertificate** typically needs **15–60 minutes *after* DNS resolves** to the Ingress IP. During this window HTTPS may 404 or show “provisioning”.

---

## Access

* **Public URLs** (example):

  * [https://obsbloc.cloudbloc.io](https://obsbloc.cloudbloc.io)
  * [https://www.obsbloc.cloudbloc.io](https://www.obsbloc.cloudbloc.io)
* **Auth**: Anonymous **Viewer** (no edits, no login)
* **HTTP→HTTPS**: Port 80 is enabled only to issue a **301** redirect to HTTPS

---

## Verify (copy/paste)

```bash
# Pods healthy?
kubectl -n obsbloc get pods

# Prometheus reachable inside cluster?
kubectl -n obsbloc port-forward deploy/prometheus 9090:9090 &
curl -s http://localhost:9090/-/ready

# Grafana reachable inside cluster?
kubectl -n obsbloc port-forward deploy/obsbloc 3000:3000 &
curl -s http://localhost:3000/api/health

# Alertmanager reachable inside cluster?
kubectl -n obsbloc port-forward deploy/alertmanager 9093:9093 &
curl -s http://localhost:9093/#/alerts
```

---

## Configuration

| Variable                    | Type           | Default                   | Description                                                     |
| --------------------------- | -------------- | ------------------------- | --------------------------------------------------------------- |
| `namespace`                 | `string`       | `obsbloc`                 | Kubernetes namespace                                            |
| `app_name`                  | `string`       | `obsbloc`                 | Prefix for Grafana resources (svc/ingress/cert)                 |
| `domains`                   | `list(string)` | *(none)*                  | Hostnames for the Ingress                                       |
| `edge_ip_name`              | `string`       | `obsbloc-edge-ip`         | Global static IP name for the Ingress                           |
| `zone_name`                 | `string`       | *(none)*                  | **Existing** Cloud DNS managed zone name (e.g., `cloudbloc-io`) |
| `grafana_image`             | `string`       | `grafana/grafana:10.4.5`  | Grafana image                                                   |
| `prometheus_image`          | `string`       | `prom/prometheus:v2.53.0` | Prometheus image                                                |
| `replicas`                  | `number`       | `1`                       | Grafana replicas                                                |
| `labels`                    | `map(string)`  | `{}`                      | Extra labels                                                    |
| `prometheus_retention`      | `string`       | `"3d"`                    | Time-based TSDB retention                                       |
| `prometheus_retention_size` | `string`       | `"8GB"`                   | Size cap for TSDB (old blocks trimmed)                          |
| `prometheus_storage_size`   | `string`       | `"10Gi"`                  | PVC size for Prometheus                                         |
| `prometheus_storage_class`  | `string`       | `"pd-standard"`           | StorageClass for PVC (supports expansion recommended)           |

---

## How it works

* **Grafana**

  * `grafana.ini` enables **anonymous** auth with `Viewer` role.
  * Datasource auto-provisioned to Prometheus at `http://prometheus.$NAMESPACE.svc.cluster.local:9090`.
  * Dashboard provider mounts dashboards from ConfigMaps.

* **Prometheus**

  * Discovers **pods that opt in** with annotations.
  * Persists data on a PVC (`prometheus-pvc-*`).
  * Trims data by time **and** by size.

* **Alertmanager**

  * Deployed with a minimal config (silent default receiver).
  * Alerts are routed internally; add a receiver to get real notifications.

* **Ingress**

  * **FrontendConfig** enforces HTTPS redirects.
  * **ManagedCertificate** covers all domains.
  * **Global static IP** + **DNS A records** ensure reachability.

---

## Troubleshooting

1. **PVC issues**

   * Default StorageClass must support expansion (`pd-standard` or `pd-balanced` on GKE).
   * If resizing, just bump `prometheus_storage_size`.
   * If you need a fresh DB, bump `data_rev` (old PVC stays until deleted).

2. **Grafana empty**

   * Verify Prometheus targets:
     `kubectl -n obsbloc port-forward deploy/prometheus 9090:9090 & curl -s localhost:9090/api/v1/targets`

3. **Alerts don’t show in Grafana**

   * Alert rules reference metrics from kube-state-metrics and apiserver; add those exporters if you want the example alerts to fire.

4. **TLS stuck in provisioning**

   * Check DNS resolves to the Ingress IP, then wait 15–60 min.

---

## Security

* Grafana is public, **read-only**.
* No admin creds are created by default.
* To add admin access:

  ```bash
  kubectl -n obsbloc create secret generic grafana-admin \
    --from-literal=GF_SECURITY_ADMIN_USER=admin \
    --from-literal=GF_SECURITY_ADMIN_PASSWORD='<strong-password>'
  ```

---

## Cost notes

* **Prometheus PVC**: \~10GiB on `pd-standard` (a few cents/month).
* **Grafana + Prometheus + Alertmanager pods**: low requests (Autopilot bills on requests).
* **Global static IP + External HTTPS LB**: standard GCP LB charges.
* No extra exporters → cardinality and costs are minimal.

---

## Uninstall

```bash
terraform destroy
# or:
kubectl -n obsbloc delete ingress,svc,deploy,cm,sa,clusterrole,clusterrolebinding --all
kubectl delete ns obsbloc
```
