# **Dropbloc Edge Nextcloud Module**

### Homelab + On-Prem Production Nextcloud on Kubernetes

This module deploys **Nextcloud at the edge** — whether that edge is:

* A **Tiny PC in your homelab**,
* A **rackmount box inside an office**,
* Or a **production on-prem environment** behind Cloudflare.

It provides a hardened, consistent deployment layer for both scenarios:

✔ Local or enterprise storage
✔ Helm-based Nextcloud deployment
✔ Automatic permissions
✔ LAN or Public access
✔ Cloudflare Zero-Trust Edge
✔ Flexible canonical URL mode (LAN/IP or Domain)

---

# **Who This Module Is For**

### 🏡 Homelab Users

* Single-node K3s
* SSD/NVMe via hostPath
* Access via LAN IP + NodePort
* Optional Cloudflare Tunnel for remote access
* “Canonical IP mode” (fastest, simplest)

### 🏢 On-Prem Production (SMB / Enterprise)

* Single-node or small cluster
* Hardened storage (NFS or local SSD)
* Strict canonical domain URLs
* Cloudflare Zero Trust perimeter
* Consistent Helm deployment
* Share links that work globally

This module adapts to both with **a single flag**.

---

# **Features**

### Storage

* HostPath static PV (homelab)
* Can be adapted to NFS / enterprise storage easily
* No need for dynamic provisioners

### Nextcloud

* Official Helm chart
* Proper securityContext + fsGroup
* NodePort or Ingress
* Customizable PHP limits
* Canonical URL abstraction layer (critical for Cloudflare + Nextcloud correctness)

### Cloudflare Edge (Optional)

* Zero Trust HTTPS without exposing router ports
* Works behind CGNAT
* Offloads TLS + WAF + geo firewalling
* Simple one-file config (credentials.json)

---

# **Deployment Profiles**

## **Profile A: Homelab Edge (Canonical IP Mode)**

Fastest. Everything behaves like a local appliance.

* Internal links generated as:

  ```
  http://10.0.0.187:30080
  ```
* Best for LAN file sync, iOS/Android auto-upload, fast UX
* Tunnel optional

Example:

```hcl
module "dropbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/dropbloc"

  namespace      = "dropbloc"
  node_ip        = "10.0.0.187"
  data_host_path = "/mnt/dropbloc/nextcloud-data"
  data_size      = "800Gi"

  nextcloud_hostname = "dropbloc.cloudbloc.io"

  # Homelab profile
  nextcloud_canonical_host     = "10.0.0.187:30080"
  nextcloud_canonical_protocol = "http"

  admin_username = "admin"
  admin_password = "supersecurepassword"

  service_node_port = 30080

  enable_cloudflared           = true
  cloudflared_credentials_file = "${path.module}/credentials.json"
  cloudflared_tunnel_id        = "YOUR_TUNNEL_ID"
}
```

---

## **Profile B: On-Prem Production Edge (Canonical Domain Mode)**

Correct behavior for companies / offices / SMBs.

* Share links →

  ```
  https://files.yourcompany.com
  ```
* Cloudflare handles HTTPS + WAF + routing
* Zero router port exposure
* Works globally on desktop/mobile apps

Example:

```hcl
module "dropbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/dropbloc"

  namespace      = "nextcloud"
  node_ip        = "192.168.10.20"
  data_host_path = "/mnt/prod-data/nextcloud"
  data_size      = "2Ti"

  nextcloud_hostname = "files.yourcompany.com"

  # Production profile (default)
  nextcloud_canonical_host     = ""      # auto = nextcloud_hostname
  nextcloud_canonical_protocol = "https"

  admin_username = "admin"
  admin_password = "change_me"

  service_node_port = 30080

  enable_cloudflared           = true
  cloudflared_credentials_file = "${path.module}/credentials.json"
  cloudflared_tunnel_id        = "YOUR_TUNNEL_ID"
}
```

---

# **Canonical URL System (Why This Matters)**

Canonical URLs tell Nextcloud:

> “This is who I *think* I am.”

Nextcloud generates:

* WebShare links
* WebDAV endpoints
* Redirects
* OAuth callback URLs

This module now supports **both worlds correctly**:

| Mode                      | When to use        | Example                     |
| ------------------------- | ------------------ | --------------------------- |
| **IP Canonical Mode**     | Homelab, LAN users | `http://10.0.0.187:30080`   |
| **Domain Canonical Mode** | On-prem production | `https://files.company.com` |

Set via:

```hcl
nextcloud_canonical_host
nextcloud_canonical_protocol
```

Defaults fit enterprise mode.

---

# **Cloudflare Tunnel Integration**

What you get:

* Public `https://yourdomain.com`
* Zero router port forwarding
* Works behind CGNAT
* Insider threats prevented
* WAF / rate limiting optional

Module generates:

```
ingress:
  - hostname: <nextcloud_hostname>
    service: http://nextcloud.<namespace>.svc.cluster.local:80
```

Fully production safe.

---

# **Host Preparation**

Create a secure storage directory:

```bash
sudo mkdir -p /mnt/dropbloc/nextcloud-data
sudo chmod 770 /mnt/dropbloc/nextcloud-data
sudo chmod 750 /mnt/dropbloc
sudo chown -R 33:33 /mnt/dropbloc/nextcloud-data
```

Works for homelab and production (just change path).

---

# **Outputs**

| Output                 | Description           |
| ---------------------- | --------------------- |
| `nextcloud_lan_url`    | Local LAN URL         |
| `nextcloud_public_url` | Public Cloudflare URL |

---

# **Best Practices**

### For Homelab:

* Use IP canonical mode for fastest UX
* Cloudflare optional
* NodePort + LAN access is ideal

### For On-Prem Production:

* Use domain canonical mode
* Enforce HTTPS
* Put Cloudflare Access policies on `/login`
* Use proper SSD/NVMe or NFS
* Ensure nightly backups of data + DB (external DB recommended in real production)
