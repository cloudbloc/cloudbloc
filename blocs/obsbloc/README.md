# Pods healthy?
kubectl -n <namespace> get pods

# Prometheus reachable inside cluster?
kubectl -n <namespace> port-forward deploy/prometheus 9090:9090 &
curl -s http://localhost:9090/-/ready

# Grafana reachable inside cluster?
kubectl -n <namespace> port-forward deploy/obsbloc 3000:3000 &
curl -s http://localhost:3000/api/health

# Ingress & cert status
kubectl -n <namespace> get ingress
kubectl -n <namespace> get managedcertificate


Grafana runs with anonymous Viewer role (no edits, no login).

Prometheus runs in-cluster, scrapes targets, and is pre-wired in Grafana as the default data source.

A dashboard provider is configured and a default dashboard JSON is mounted, so the first screen isn’t empty.

GCE Ingress terminates TLS via ManagedCertificate, routes to the Grafana Service (NEG annotation included).

DNS A record(s) are created in your existing Cloud DNS zone (zone_name) pointing at the global static IP.

A few real-world notes so you’re not surprised:

TLS issuance delay: Google ManagedCertificate typically needs 15–60 minutes after DNS is live. You’ll see 404/HTTP or “provisioning” until it’s ready.

DNS must exist: The module assumes var.zone_name already exists and hosts the parent domain (e.g., cloudbloc.io).

GKE Ingress: Make sure your cluster has the GCE Ingress controller (standard on GKE).

RBAC is minimal: You’ll see up targets from Prometheus and pod/node discovery. (Scraping kubelet/cAdvisor would require extra auth you can add later.)