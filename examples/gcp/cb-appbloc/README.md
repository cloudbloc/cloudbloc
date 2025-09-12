# `blocs/appbloc/examples/existing-dns/`

> Use an **existing** Cloud DNS managed zone (recommended for most users).

**versions.tf**

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = { source = "hashicorp/google",     version = ">= 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.25" }
  }
}
```

**providers.tf**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  project  = var.project_id
  location = var.location   # use location here (zonal or regional)
  name     = var.cluster_name
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}
```

**variables.tf**

```hcl
variable "project_id"   { type = string }
variable "region"       { type = string }               # e.g. "us-central1"
variable "location"     { type = string }               # e.g. "us-central1-a" or "us-central1"
variable "cluster_name" { type = string }

variable "domains"      { type = list(string) }         # e.g. ["app.example.com","www.app.example.com"]
variable "dns_zone_name" { type = string }              # existing zone name, e.g. "example-com"
variable "edge_ip_name" { type = string }               # global static IP resource name

variable "app_namespace" { type = string, default = "appbloc" }
variable "app_image"     { type = string, default = "nginx:stable-alpine" }
variable "app_port"      { type = number, default = 80 }
variable "app_replicas"  { type = number, default = 2 }
variable "environment"   { type = string, default = "prd" }

variable "enable_static_html" { type = bool, default = false }
variable "html_path"          { type = string, default = "index.html" }

variable "cloudarmor_policy" {
  type        = string
  default     = null
  description = "Optional: projects/<proj>/global/securityPolicies/<name>"
}
```

**main.tf**

```hcl
locals {
  env           = var.environment
  html_abs_path = "${path.root}/static/${var.html_path}"
}

module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/appbloc?ref=appbloc-0.3.0"

  namespace            = var.app_namespace
  app_name             = "cloudbloc-webapp-${var.environment}"

  image                = var.app_image
  replicas             = var.app_replicas
  container_port       = var.app_port

  domains              = var.domains
  edge_ip_name         = var.edge_ip_name
  cloudarmor_policy    = var.cloudarmor_policy

  create_dns_zone      = false
  dns_zone_name        = var.dns_zone_name

  enable_static_html   = var.enable_static_html
  html_path            = local.html_abs_path

  labels = { env = local.env }
}
```

**static/index.html**

```html
<!doctype html>
<title>appbloc • existing-dns</title>
<h1>✅ appbloc (existing-dns) is live</h1>
<p>Served via GCLB + ManagedCertificate + HTTP→HTTPS redirect.</p>
```

---

# 📁 `blocs/appbloc/examples/create-dns-zone/`

> Create a **new** Cloud DNS managed zone from `domains[0]`.

**versions.tf**

```hcl
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = { source = "hashicorp/google",     version = ">= 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.25" }
  }
}
```

**providers.tf**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  project  = var.project_id
  location = var.location
  name     = var.cluster_name
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.gke.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}
```

**variables.tf**

```hcl
variable "project_id"   { type = string }
variable "region"       { type = string }
variable "location"     { type = string }
variable "cluster_name" { type = string }

variable "domains"      { type = list(string) }  # e.g. ["example.com", "www.example.com"]
variable "edge_ip_name" { type = string }

variable "app_namespace" { type = string, default = "appbloc" }
variable "app_image"     { type = string, default = "nginx:stable-alpine" }
variable "app_port"      { type = number, default = 80 }
variable "app_replicas"  { type = number, default = 2 }
variable "environment"   { type = string, default = "prd" }

variable "enable_static_html" { type = bool, default = true }
variable "html_path"          { type = string, default = "index.html" }

variable "cloudarmor_policy" {
  type        = string
  default     = null
  description = "Optional: projects/<proj>/global/securityPolicies/<name>"
}
```

**main.tf**

```hcl
locals {
  env           = var.environment
  html_abs_path = "${path.root}/static/${var.html_path}"
}

module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/appbloc?ref=appbloc-0.2.0"

  namespace            = var.app_namespace
  app_name             = "cloudbloc-webapp-${var.environment}"

  image                = var.app_image
  replicas             = var.app_replicas
  container_port       = var.app_port

  domains              = var.domains
  edge_ip_name         = var.edge_ip_name
  cloudarmor_policy    = var.cloudarmor_policy

  create_dns_zone      = true

  enable_static_html   = var.enable_static_html
  html_path            = local.html_abs_path

  labels = { env = local.env }
}
```

**static/index.html**

```html
<!doctype html>
<title>appbloc • create-dns-zone</title>
<h1>🚀 appbloc (create-dns-zone) is live</h1>
<p>This example created a new Cloud DNS zone from <code>domains[0]</code>.</p>
```

---

## Run steps (both examples)

```bash
terraform init
terraform apply

# Wait a few minutes for the ManagedCertificate to be Active:
kubectl -n appbloc describe managedcertificate

# Check redirect and TLS
curl -I http://<your-domain>  | grep -i location
curl -I https://<your-domain>
```
