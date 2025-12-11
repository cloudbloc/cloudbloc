# 🧱 **Appbloc (Edge) — Homelab & On-Prem App Deployment Module**

**Cloudbloc Edge** version of Appbloc — deploy any containerized app into your homelab/on-prem Kubernetes cluster **with zero cloud dependency**, using:

* **NodePort** for LAN access
* **Cloudflare Tunnel** for public HTTPS access
* **Static file hosting** (optional)
* **ConfigMap-mounted HTML**
* **Simple env injection**
* **Zero Ingress, Zero Load Balancer, Zero SSL config**

This module is designed for **K3s, MicroK8s, and bare-metal Kubernetes**.

---

# 🚀 Features

### ✔️ Deploy any container

Provide an image + port → Appbloc deploys the app.

### ✔️ Optional static website mode

Mounts an HTML file directly into `/usr/share/nginx/html`.

### ✔️ Native Cloudflare Tunnel integration

Appbloc automatically deploys:

* cloudflared Deployment
* cloudflared ConfigMap
* cloudflared credentials Secret
* ingress routing for hostname + [www](http://www).<hostname>

No LB, no ingress controllers, no SSL management.

### ✔️ Pure Kubernetes objects

No cloud provider dependencies. Runs anywhere.

---

# 📦 Module Inputs

### Required

| Variable         | Description                           |
| ---------------- | ------------------------------------- |
| `namespace`      | Kubernetes namespace                  |
| `app_name`       | App name used in Deployment + Service |
| `image`          | Container image                       |
| `container_port` | Port your app listens on              |
| `node_port`      | NodePort exposed on your homelab      |

### Optional

| Variable             | Type        | Description                             |
| -------------------- | ----------- | --------------------------------------- |
| `enable_static_html` | bool        | Serve a static index.html via ConfigMap |
| `html_path`          | string      | Absolute path to HTML file              |
| `env`                | map(string) | Environment variables                   |
| `replicas`           | number      | Defaults to 1                           |

### Cloudflare Tunnel (optional)

If `enable_cloudflared = true`:

| Variable                       | Description                                     |
| ------------------------------ | ----------------------------------------------- |
| `cloudflared_tunnel_id`        | UUID of your Cloudflare Tunnel                  |
| `cloudflared_hostname`         | Domain the tunnel should serve                  |
| `cloudflared_credentials_json` | Contents of `<tunnel-id>.json` credentials file |

---

# 📁 Example Usage

Assuming your Terraform root has:

```
static/index.html
credentials.json
```

And you want to serve `cloudbloc.io` from your homelab:

```hcl
locals {
  env           = var.environment
  html_abs_path = "${path.root}/static/${var.html_path}"
}

module "appbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/appbloc"

  namespace      = var.app_namespace
  app_name       = "cloudbloc-webapp-${var.environment}"
  image          = "nginx:stable"
  container_port = 80
  replicas       = 1

  labels = {
    env = local.env
  }

  # Static site hosting
  enable_static_html = true
  html_path          = local.html_abs_path

  # LAN NodePort
  node_port = 30081

  # Enable Cloudflare Tunnel for HTTPS public access
  enable_cloudflared           = true
  cloudflared_tunnel_id        = "109c1cc5-0788-4761-bbe6-06cfd05c769f"
  cloudflared_hostname         = "cloudbloc.io"
  cloudflared_credentials_json = file("${path.module}/credentials.json")
}
```

---

# 🌐 Setting Up Cloudflare Tunnel (One-Time)

1. Authenticate:

```bash
cloudflared tunnel login
```

2. Create tunnel:

```bash
cloudflared tunnel create appbloc-tunnel
```

3. Credentials file is created at:

```
~/.cloudflared/<tunnel-id>.json
```

4. Copy it into your repo:

```bash
cp ~/.cloudflared/<id>.json edge-appbloc/credentials.json
```

5. Add DNS routes:

```bash
cloudflared tunnel route dns appbloc-tunnel cloudbloc.io
cloudflared tunnel route dns appbloc-tunnel www.cloudbloc.io
```

---

# 🕸️ Architecture

```
Internet
   |
Cloudflare (proxy + SSL + WAF)
   |
Cloudflare Tunnel
   |
cloudflared pod (inside your cluster)
   |
Kubernetes Service (NodePort: 30081)
   |
Kubernetes Deployment (your app)
```

### No:

✘ Load balancer
✘ Ingress controller
✘ SSL certificates
✘ Public IP

### Yes:

✔ Secure HTTPS
✔ Free Cloudflare proxy
✔ Instant DNS
✔ Works even behind NAT

---

# 🔧 Local LAN Access

Even with Cloudflare Tunnel, you can still reach the app at:

```
http://<local-ip>:30081
```

Great for:

* debugging
* large file transfers
* local-only workflows

---

# 🔒 Security Notes

* Cloudflare Tunnel credentials are **sensitive**
* Never commit `credentials.json` to public repos
* Use Vault/SOPS if possible
* Cloudflare protects your origin from exposure
* Tunnel only allows outbound traffic → safe behind NAT

---

# 🧪 Testing

### Check pods:

```bash
kubectl get pods -n appbloc
```

### Test tunnel:

```bash
kubectl logs -n appbloc deploy/cloudflared -f
```

### Test LAN:

```bash
curl http://10.0.0.187:30081
```

### Test public:

```
https://cloudbloc.io
```

---

# 🧨 Troubleshooting

### Tunnel shows 404?

Ensure ConfigMap includes:

```
- hostname: cloudbloc.io
- hostname: www.cloudbloc.io
```

### Error: “record already exists”

Delete old CNAME in Cloudflare DNS UI.

### Nothing loads?

Check if app port matches your container port.

### LAN works but public doesn’t?

Check cloudflared logs:

```bash
kubectl logs deploy/cloudflared -n appbloc
```

---

# 🏁 Summary

Appbloc (Edge) gives you:

* **Production-grade deployments**
* **Public HTTPS for any app in your homelab**
* **Cloudflare-powered global ingress**
* **Zero cloud cost**
* **Minimal Kubernetes footprint**
* **Static site or dynamic container support**

It is the foundation for:

* personal sites
* microservices
* dashboards
* APIs
* frontend SPAs
* automation apps

Anything you can containerize → Appbloc can expose it globally.
