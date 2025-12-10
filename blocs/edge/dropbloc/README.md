# 🧊 **Dropbloc Nextcloud (Homelab / On-Prem Edge Module)**

A production-ready, self-hosted **Nextcloud** module designed for:

* Homelabs (Tiny PC, NUC, Lenovo Tiny)
* External SSD / NVMe local storage
* On-prem production nodes
* Optional **Cloudflare Tunnel** for secure HTTPS without exposing ports

This module gives you:

* Local persistent storage via `hostPath`
* Static PV + PVC (no dynamic provisioning required)
* Nextcloud deployed via official Helm
* Automatic permission fix via `fsGroup=33`
* Optional Cloudflare Tunnel → public domain → Nextcloud
* Works for **LAN-only** or **LAN + Cloudflare public access**

Everything is fully automated through Terraform.

---

# 🧩 **What You Need To Provide**

### Required (everyone)

| Variable                           | Description                                        |
| ---------------------------------- | -------------------------------------------------- |
| `node_ip`                          | LAN IP of your Tiny or node (ex: `192.168.1.50`)   |
| `data_host_path`                   | Directory on your SSD/NVMe to store Nextcloud data |
| `admin_username`, `admin_password` | Nextcloud admin login                              |

### Required only if using Cloudflare Tunnel

| Variable                       | Description                             |
| ------------------------------ | --------------------------------------- |
| `nextcloud_hostname`           | Ex: `cloud.mydomain.com`                |
| `cloudflared_credentials_file` | Path to **your** Tunnel credential JSON |
| `cloudflared_tunnel_id`        | Your Cloudflare Tunnel UUID             |

⚠️ **Every user needs their own Cloudflare Tunnel and credentials.json.**
Your tunnel and credentials cannot be reused by others.

---

# 📦 **1. Prepare Storage on Your Tiny**

This is the only manual step:

```bash
sudo mkdir -p /mnt/dropbloc/nextcloud-data
sudo chmod 770 /mnt/dropbloc/nextcloud-data
sudo chmod 750 /mnt/dropbloc
sudo chown -R 33:33 /mnt/dropbloc/nextcloud-data
```

Works for:

* SATA SSD
* NVMe SSD in USB enclosure
* Internal NVMe
* ANY filesystem mounted on the host

If the directory exists and is writable, Dropbloc will use it.

---

# 🚀 **2. Example Usage: LAN-Only Setup (no Cloudflare)**

This is the simplest setup.
Nextcloud is only available on your **local network**.

```hcl
module "dropbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/dropbloc"

  namespace      = "dropbloc"
  node_ip        = "192.168.1.50"
  data_host_path = "/mnt/dropbloc/nextcloud-data"
  data_size      = "800Gi"

  # Canonical host tells Nextcloud what URLs to generate internally
  nextcloud_canonical_host     = "192.168.1.50:30080"
  nextcloud_canonical_protocol = "http"

  # You can leave hostname blank if not using Cloudflare
  nextcloud_hostname = ""

  admin_username = "admin"
  admin_password = "change_me"

  service_node_port      = 30080
  enable_cloudflared = false
}
```

After apply:

👉 **Open Nextcloud:**
`http://192.168.1.50:30080`

---

# 🌐 **3. Example Usage: LAN + Cloudflare Tunnel (Public HTTPS)**

To expose Nextcloud globally without opening ports:

Prerequisites:

* Domain in Cloudflare
* A Cloudflare Tunnel
* Downloaded `credentials.json`

Then use this:

```hcl
module "dropbloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/dropbloc"

  namespace      = "dropbloc"
  node_ip        = "192.168.1.50"
  data_host_path = "/mnt/dropbloc/nextcloud-data"
  data_size      = "800Gi"

  # Public hostname used by Cloudflare + canonical URLs
  nextcloud_hostname           = "cloud.mydomain.com"
  nextcloud_canonical_host     = "cloud.mydomain.com"
  nextcloud_canonical_protocol = "https"

  admin_username = "admin"
  admin_password = "change_me"

  service_node_port      = 30080
  php_memory_limit       = "2048M"
  php_upload_limit       = "16G"
  php_max_execution_time = 3600

  enable_cloudflared = true

  # USER-SPECIFIC:
  cloudflared_credentials_file = abspath("${path.module}/credentials.json")
  cloudflared_tunnel_id        = "YOUR-TUNNEL-ID"
}
```

After apply:

👉 **LAN Access:**
`http://192.168.1.50:30080`

👉 **Public HTTPS Access:**
`https://cloud.mydomain.com`

---

# 🛠️ **4. Outputs**

After `apply`, Terraform prints:

```txt
nextcloud_lan_url    = http://192.168.1.50:30080
nextcloud_public_url = cloud.mydomain.com
```

---

# 🧪 **5. Tips & Best Practices**

### Storage

* You can mount **any external SSD/NVMe**
* Works with `/mnt/ssd1`, `/mnt/nvme0`, etc.
* Must be formatted & mounted before applying Terraform.

### Security

* LAN IP (e.g., `192.168.1.50`) is **not public**
* Even if someone joins your WiFi, they can easily discover LAN hosts:

  * `arp -a`
  * `nmap -sn 192.168.1.0/24`
* Use a strong admin password
* Cloudflare Tunnel + HTTPS is recommended for external access

### Performance

* NVMe performs amazingly
* HostPath → fastest possible I/O
* Local-only deployment avoids cloud storage costs entirely
