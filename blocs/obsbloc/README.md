# ObsBloc (Grafana + Prometheus) for GKE

A tiny, production-lean **observability bloc** that exposes a **public, read-only Grafana** at your domain, backed by a **lightweight in-cluster Prometheus**. Built for **GKE + GCE Ingress** with **ManagedCertificate** and **HTTP→HTTPS redirect**.

---

## What gets created

- **Grafana**
  - Anonymous **Viewer** access (no edits, no login)
  - Pre-provisioned **Prometheus** datasource
  - Dashboard **provider** + a default dashboard so the first screen isn’t empty
- **Prometheus**
  - 1 replica, 1-day retention
  - Kubernetes **pod** and **node** discovery (minimal RBAC)
- **Networking**
  - **GCE Ingress** (NEG) with **ManagedCertificate**
  - **FrontendConfig** to 301 redirect **HTTP → HTTPS**
  - **Global static IP**
  - **DNS A records** in your **existing** Cloud DNS zone (`zone_name`)

---

## Requirements

- A **GKE** cluster with the **GCE Ingress** controller (standard on GKE)
- A **Cloud DNS** managed zone for your parent domain already exists (e.g., `cloudbloc.io`)
- `terraform`, `kubectl`, `gcloud` authenticated to your project and cluster

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
}
````

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

> If you used defaults, `<namespace>` is `obsbloc`.

### Pods healthy?

```bash
kubectl -n <namespace> get pods
```

### Prometheus reachable inside cluster?

```bash
kubectl -n <namespace> port-forward deploy/prometheus 9090:9090 &
curl -s http://localhost:9090/-/ready
```

### Grafana reachable inside cluster?

```bash
kubectl -n <namespace> port-forward deploy/obsbloc 3000:3000 &
curl -s http://localhost:3000/api/health
```

### Ingress & certificate status

```bash
kubectl -n <namespace> get ingress
kubectl -n <namespace> get managedcertificate
```

### End-to-end (IP ⇄ DNS ⇄ Ingress ⇄ Svc)

```bash
# Ingress IP
kubectl -n obsbloc get ingress obsbloc-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; echo

# DNS should resolve to the SAME IP
dig +short obsbloc.cloudbloc.io
dig +short www.obsbloc.cloudbloc.io

# ManagedCertificate detail (should become "Active")
kubectl -n obsbloc describe managedcertificate obsbloc-cert | sed -n '1,120p'

# Ingress detail (annotations, rules, backends)
kubectl -n obsbloc describe ingress obsbloc-ingress

# Service detail (NEG annotation, ports)
kubectl -n obsbloc describe svc obsbloc-svc | sed -n '1,200p'

# Grafana rollout, logs, in-pod health check
kubectl -n obsbloc get deploy,po -l app=obsbloc
kubectl -n obsbloc logs deploy/obsbloc --tail=60
kubectl -n obsbloc exec deploy/obsbloc -- wget -qO- http://127.0.0.1:3000/api/health
```

---

## Configuration

| Variable           | Type           | Default                   | Description                                                          |
| ------------------ | -------------- | ------------------------- | -------------------------------------------------------------------- |
| `namespace`        | `string`       | `obsbloc`                 | Kubernetes namespace                                                 |
| `app_name`         | `string`       | `obsbloc`                 | Prefix for Grafana resources (svc/ingress/cert)                      |
| `domains`          | `list(string)` | *(none)*                  | Hostnames for the Ingress (e.g., `["obsbloc.cloudbloc.io","www.…"]`) |
| `edge_ip_name`     | `string`       | `obsbloc-edge-ip`         | Global static IP name for the Ingress                                |
| `zone_name`        | `string`       | *(none)*                  | **Existing** Cloud DNS managed **zone name** (e.g., `cloudbloc-io`)  |
| `grafana_image`    | `string`       | `grafana/grafana:latest`  | Pin to a version for reproducibility                                 |
| `prometheus_image` | `string`       | `prom/prometheus:v2.53.0` | Prometheus image                                                     |
| `replicas`         | `number`       | `1`                       | Grafana replicas                                                     |
| `labels`           | `map(string)`  | `{}`                      | Extra labels                                                         |

---

## How it works

* **Grafana**

  * `grafana.ini` enables **anonymous** auth with `Viewer` role.
  * Datasource is auto-provisioned to Prometheus at `http://prometheus.$NAMESPACE.svc.cluster.local:9090`.
  * A dashboard **provider** is configured; a small default dashboard JSON is mounted.
* **Prometheus**

  * Discovers **pods** and **nodes** (RBAC read-only) with 1-day retention.
* **Ingress**

  * `kubernetes.io/ingress.allow-http: "true"` (listener for redirect)
  * **FrontendConfig** enforces **301** redirect to **HTTPS**
  * **ManagedCertificate** serves TLS for all `var.domains`
* **DNS**

  * Creates **A records only** in your existing managed zone pointing at the Ingress global IP.

---

## Troubleshooting

1. **TLS “Provisioning” / HTTPS 404**

   * Confirm DNS A records exist and resolve to the Ingress IP.
   * Wait 15–60 minutes after DNS is live.
   * Check: `kubectl -n obsbloc get managedcertificate obsbloc-cert -o yaml`.

2. **HTTP doesn’t redirect**

   * Ingress must include:

     * `kubernetes.io/ingress.allow-http: "true"`
     * `networking.gke.io/v1beta1.FrontendConfig: obsbloc-frontendconfig`
   * FrontendConfig must set `redirectToHttps.enabled: true`.

3. **Ingress 404 but backends healthy**

   * Ensure Service has the NEG annotation (`cloud.google.com/neg: {"ingress": true}`) and the Ingress default backend is `obsbloc-svc:80`.

4. **Grafana empty**

   * Verify Prometheus targets: `curl localhost:9090/api/v1/targets` (via port-forward).
   * RBAC is minimal (pods/nodes). For kubelet/cAdvisor or richer metrics, add node-exporter/kube-state-metrics later.

5. **Re-apply wobble**

   * Ingress updates can briefly 404 while the LB reconfigures.
   * Worst case, recreate cleanly:

     ```bash
     kubectl -n obsbloc delete ingress obsbloc-ingress
     terraform apply
     ```

---

## Security

* Public **read-only** Grafana via anonymous `Viewer`.
* No admin credentials are created by default.
* **Optional private admin** (example):

  ```bash
  kubectl -n obsbloc create secret generic grafana-admin \
    --from-literal=GF_SECURITY_ADMIN_USER=admin \
    --from-literal=GF_SECURITY_ADMIN_PASSWORD='<strong-password>'
  ```

  Then patch the Deployment to `envFrom` that Secret (or wire via Terraform) and keep the site public, or gate with IAP/Cloud Armor later.

---

## Cost notes

* Small CPU/memory requests; 1-day Prometheus retention.
* One global static IP + External HTTP(S) Load Balancer.
* No extra collectors by default (keeps cost minimal).

---

## Uninstall

```bash
terraform destroy
# or:
kubectl -n obsbloc delete ingress,svc,deploy,cm,sa,clusterrole,clusterrolebinding --all
kubectl delete ns obsbloc
```