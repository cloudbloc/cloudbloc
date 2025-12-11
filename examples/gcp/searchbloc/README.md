# searchbloc — SearchBloc (Meilisearch) Demo

A minimal, production‑lean demo of **SearchBloc** powered by **Meilisearch** on GKE. This README walks you from zero → searchable UI using a realistic `products` index.

> **Default public endpoint in examples:** `https://searchbloc.cloudbloc.io/api`
> (Your Ingress/Nginx proxy maps `/api/*` → Meilisearch on `127.0.0.1:7700`.)

---

## What you get

* **Meilisearch** deployed in Kubernetes (PVC-backed).
* **Nginx reverse proxy**: `/` serves static UI, `/api/*` proxies to Meili.
* **Public search-only API key** for browser demos.
* A ready-to-query **`products`** index with sensible settings & sample data hooks.

---

## Prerequisites

* GKE cluster reachable by `kubectl`/Terraform (or your Kubernetes cluster of choice).
* Terraform installed (>= 1.5 recommended).
* `curl`, `jq` for quick tests.
* A Meili **master key** you will use for provisioning (never expose to browsers).

> If you deployed via the Terraform module, you likely supplied `var.master_key` already. Use that same value here.

---

## Quick Start (10–15 min)

### 0) Environment

Export the master key you used to deploy Meilisearch (or plan to use):

```bash
export searchbloc_master_key="<your_meili_master_key>"
export MEILI_ENDPOINT="https://searchbloc.cloudbloc.io/api"
```

> If your endpoint differs (e.g., internal port-forward):
>
> ```bash
> export MEILI_ENDPOINT="http://127.0.0.1:7700"
> ```

### 1) Deploy / Update SearchBloc (Terraform)

If you haven’t deployed the bloc yet, or you’ve just pulled fresh code:

```bash
# Optional: pass the master key to Terraform if your module expects it
export TF_VAR_master_key="$searchbloc_master_key"

terraform init
terraform apply
```

This creates/updates the namespace, PVC, Meili Deployment/Service, Nginx proxy, Ingress, and (optionally) Managed Certificate + Cloud Armor if configured.

### 2) Create a **public, search-only** API key (for the browser)

> **Never** ship your master key to the browser. Create a scoped, expiring key.

**macOS (BSD date):**

```bash
curl --fail-with-body -S -s -X POST "$MEILI_ENDPOINT/keys" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  -d "{\
    \"name\": \"PublicSearch\",\
    \"description\": \"Browser search-only key\",\
    \"actions\": [\"search\"],\
    \"indexes\": [\"products\"],\
    \"expiresAt\": \"$(date -u -v+30d +%Y-%m-%dT%H:%M:%SZ)\"\
  }"
```

**Linux (GNU date):**

```bash
curl --fail-with-body -S -s -X POST "$MEILI_ENDPOINT/keys" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  -d "{\
    \"name\": \"PublicSearch\",\
    \"description\": \"Browser search-only key\",\
    \"actions\": [\"search\"],\
    \"indexes\": [\"products\"],\
    \"expiresAt\": \"$(date -u -d '+30 days' +%Y-%m-%dT%H:%M:%SZ)\"\
  }"
```

> 🔐 **Least privilege**: prefer `\"indexes\": [\"products\"]` over `*` in production demos.

The response contains `key` — copy it and export for Terraform wiring (if your UI consumes it via TF):

```bash
export TF_VAR_public_search_key="<the_key_value_from_response>"
terraform apply
```

### 3) Create the `products` index

```bash
curl -S -s -X POST "$MEILI_ENDPOINT/indexes" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{"uid":"products","primaryKey":"id"}' | jq .
```

### 4) Tune index settings (searchable/filterable/sortable/displayed)

```bash
curl -S -s -X PATCH "$MEILI_ENDPOINT/indexes/products/settings" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{
    "searchableAttributes": ["name","brand","description","tags","categories"],
    "filterableAttributes":  ["brand","categories","colors","sizes","in_stock","price","rating","created_at"],
    "sortableAttributes":    ["price","rating","reviews","created_at","name"],
    "displayedAttributes":   ["id","name","brand","categories","price","rating","reviews","colors","in_stock","image_url","thumb_url","description"],
    "faceting": { "maxValuesPerFacet": 30 }
  }' | jq .
```

### 5) Seed documents

Place a seed file at repo root (or provide a path) then import. The file can be a JSON **array** of objects.

```bash
# Example import (array JSON)
curl -S -s -X POST "$MEILI_ENDPOINT/indexes/products/documents?primaryKey=id" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data-binary @products_seed_500.json | jq .
```

> **Tip:** You can also send NDJSON (`--data-binary @file.ndjson`).

### 6) Verify search

```bash
# List indexes
curl -s -H "Authorization: Bearer $searchbloc_master_key" "$MEILI_ENDPOINT/indexes" | jq .

# Simple query
curl -s -X POST "$MELI_ENDPOINT/indexes/products/search" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{"q":"shoes"}' | jq '.hits[0:3]'

# Faceted + sorted
curl -s -X POST "$MEILI_ENDPOINT/indexes/products/search" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{
    "q": "running",
    "filter": ["brand = Nike", "in_stock = true", "price < 200"],
    "sort":   ["price:asc"],
    "facets": ["brand","categories","colors","sizes"]
  }' | jq '.hits[0:3]'
```

### 7) Open the demo UI

Open your public URL (root path). The UI should be configured to call:

```
GET/POST  $MEILI_ENDPOINT/indexes/products/search
Auth:     Bearer <PublicSearch key>
```

If your UI reads `TF_VAR_public_search_key`, re‑`terraform apply` after updating it.

---

## Module / Variables (common)

Depending on your module version, the following variables are typical:

* `namespace` — Kubernetes namespace for SearchBloc (e.g., `searchbloc` or `obsbloc`).
* `app_name` — App label/name (e.g., `searchbloc`).
* `master_key` — Meili master key (string). **Required.**
* `public_search_key` — Optional; propagated to UI config/ConfigMap.
* `storage_size` — PVC size (e.g., `5Gi`).
* `storage_class_name` — Optional StorageClass name.
* `cloudarmor_policy` — Optional. Attach a Cloud Armor policy to Ingress.
* `edge_ip_name`, `managed_certificate` — Optional ingress/cert wiring.

> Check your module’s `variables.tf` for the authoritative list.

---

## Security Notes

* **Never** expose the master key to browsers or untrusted CI logs.
* Prefer **index‑scoped** public keys (`indexes: ["products"]`) with **short expirations** (e.g., 30 days) and rotate.
* If using a shared LB (e.g., with ObsBloc), ensure **HTTPS redirect** and **Cloud Armor** are applied at the Ingress.

---

## Troubleshooting

* **403 Forbidden** when creating keys: wrong/missing `Authorization` header or incorrect master key.
* **Index not found**: create it (`/indexes` POST) before updating settings or seeding.
* **CORS issues in browser**: ensure your Nginx or Ingress adds proper CORS headers (or proxy from same origin).
* **502/504 via Ingress**: check Service/Pod status; confirm Nginx proxy target is `127.0.0.1:7700`.
* **413 Payload Too Large** when importing: split seed file, or increase proxy/body size limits in Nginx/Ingress.

---

## Maintenance / Ops

* **Backups**: snapshot PVC or export documents via `/indexes/<uid>/documents`.
* **Scaling**: add CPU/memory or tune Meili indexer options. Enable HPA on Nginx/Meili if desired.
* **Logs**: forward Nginx/Meili logs to your Observability stack (ObsBloc) or Cloud Logging.

---

## API Cheat Sheet (copy‑paste friendly)

```bash
# Set endpoint/master key
export MEILI_ENDPOINT="https://searchbloc.cloudbloc.io/api"
export searchbloc_master_key="<master>"

# Create a search-only key (macOS; limit to products)
curl -S -s -X POST "$MEILI_ENDPOINT/keys" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  -d "{\
    \"name\": \"PublicSearch\",\
    \"description\": \"Browser search-only key\",\
    \"actions\": [\"search\"],\
    \"indexes\": [\"products\"],\
    \"expiresAt\": \"$(date -u -v+30d +%Y-%m-%dT%H:%M:%SZ)\"\
  }"

# Export for Terraform/UI and apply
export TF_VAR_public_search_key="<key_from_above>"
terraform apply

# Create index
curl -S -s -X POST "$MEILI_ENDPOINT/indexes" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{"uid":"products","primaryKey":"id"}'

# Configure settings
curl -S -s -X PATCH "$MEILI_ENDPOINT/indexes/products/settings" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{
    "searchableAttributes": ["name","brand","description","tags","categories"],
    "filterableAttributes":  ["brand","categories","colors","sizes","in_stock","price","rating","created_at"],
    "sortableAttributes":    ["price","rating","reviews","created_at","name"],
    "displayedAttributes":   ["id","name","brand","categories","price","rating","reviews","colors","in_stock","image_url","thumb_url","description"],
    "faceting": { "maxValuesPerFacet": 30 }
  }'

# Seed documents (array JSON)
curl -S -s -X POST "$MEILI_ENDPOINT/indexes/products/documents?primaryKey=id" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data-binary @products_seed_500.json

# Verify search
curl -s -X POST "$MEILI_ENDPOINT/indexes/products/search" \
  -H "Authorization: Bearer $searchbloc_master_key" \
  -H "Content-Type: application/json" \
  --data '{"q":"shoes"}' | jq '.hits[0:5]'
```

---

## Cleanup

```bash
# Delete the search-only key
# 1) List keys to find the key ID
echo "List keys:" && curl -s -H "Authorization: Bearer $searchbloc_master_key" "$MEILI_ENDPOINT/keys" | jq '.[].uid? // .results[]?.uid? // .'
# 2) Delete by key UID (replace <uid>)
curl -X DELETE "$MEILI_ENDPOINT/keys/<uid>" -H "Authorization: Bearer $searchbloc_master_key"

# Drop the index
curl -X DELETE "$MEILI_ENDPOINT/indexes/products" -H "Authorization: Bearer $searchbloc_master_key"
```

---

## Notes

* If SearchBloc shares an HTTPS LB with ObsBloc, you don’t need a separate LB; just ensure the **FrontendConfig** forces HTTPS redirect and **Cloud Armor** is attached at the Ingress.
* Use **restricted** public keys in demos; rotate monthly or per event.
* For another vertical (docs/movies), replace the `uid` and attribute lists accordingly.
