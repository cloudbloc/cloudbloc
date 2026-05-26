# 🧊 **Dropbloc Nextcloud (Homelab / On-Prem Edge Module)**

A production-ready, self-hosted **Nextcloud** module designed for:

* Homelabs (Local PC, NUC, Lenovo Tiny)
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
| `node_ip`                          | LAN IP of your local or node (ex: `192.168.1.50`)   |
| `data_host_path`                   | Directory on your SSD/NVMe to store Nextcloud data |
| `admin_username`, `admin_password` | Nextcloud admin login                              |

### Required only if using Cloudflare Tunnel

| Variable                       | Description                             |
| ------------------------------ | --------------------------------------- |
| `nextcloud_hostname`           | Ex: `dropbloc.cloudbloc.io`                |
| `cloudflared_credentials_file` | Path to **your** Tunnel credential JSON |
| `cloudflared_tunnel_id`        | Your Cloudflare Tunnel UUID             |

⚠️ **Every user needs their own Cloudflare Tunnel and credentials.json.**
Your tunnel and credentials cannot be reused by others.

---

# 📦 **1. Prepare Storage on Local**

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

# 🔁 **2. Manual Restore Checklist**

To reproduce a Dropbloc deployment on a fresh local node or Tiny, do these manual steps before running Terraform:

1. Install the OS and Kubernetes on the node.

   Dropbloc expects a working Kubernetes cluster. Installing k3s, MicroK8s, or another Kubernetes distribution is outside this module.

2. Assign a stable LAN IP.

   Reserve or statically configure the IP you will pass as `node_ip`, for example:

   ```hcl
   node_ip = "192.168.1.50"
   ```

3. Mount persistent storage.

   Format and mount the SSD/NVMe/disk that will back `data_host_path`. The mount must survive reboot.

4. Prepare the Nextcloud data directory on the node.

   ```bash
   sudo mkdir -p /mnt/dropbloc/nextcloud-data
   sudo chmod 750 /mnt/dropbloc
   sudo chmod 770 /mnt/dropbloc/nextcloud-data
   sudo chown -R 33:33 /mnt/dropbloc/nextcloud-data
   ```

5. Copy kubeconfig to the machine running Terraform.

   Point the Kubernetes and Helm providers at that kubeconfig, then verify access:

   ```bash
   kubectl --kubeconfig ~/.kube/edge get nodes
   ```

6. If using Cloudflare Tunnel, create or restore the tunnel.

   Create the tunnel in your Cloudflare account, route your hostname to it, and keep the generated `credentials.json` outside git.

   ```hcl
   nextcloud_hostname           = "dropbloc.cloudbloc.io"
   cloudflared_tunnel_id        = "123e4567-e89b-12d3-a456-426614174000"
   cloudflared_credentials_file = abspath("${path.module}/credentials.json")
   ```

7. Provide secrets through local inputs.

   Use a strong `admin_password`. Do not commit real passwords, kubeconfigs, tunnel credentials, or `.tfvars` files containing secrets.

8. Initialize and apply Terraform from your Dropbloc root.

   If your root uses a remote backend, make sure the backend bucket/state location already exists and your local credentials can access it.

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

9. Validate the deployment.

   ```bash
   kubectl -n dropbloc get all
   kubectl -n dropbloc get cronjob nextcloud-cron
   curl http://192.168.1.50:30080
   ```

---

# 🚀 **3. Example Usage: LAN-Only Setup (no Cloudflare)**

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

# 🌐 **4. Example Usage: LAN + Cloudflare Tunnel (Public HTTPS)**

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
  nextcloud_hostname           = "dropbloc.cloudbloc.io"
  nextcloud_canonical_host     = "dropbloc.cloudbloc.io"
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
  cloudflared_tunnel_id        = "123e4567-e89b-12d3-a456-426614174000"
}
```

After apply:

👉 **LAN Access:**
`http://192.168.1.50:30080`

👉 **Public HTTPS Access:**
`https://dropbloc.cloudbloc.io`

---

# ⏱ **5. Nextcloud Cron Runner**

Nextcloud’s `backgroundjobs_mode = cron` requires `cron.php` to run frequently or file metadata (like uploads created by other pods) will fall behind. Dropbloc enables the Helm chart’s built-in CronJob (`nextcloud-cron`) so Kubernetes handles `php -f /var/www/html/cron.php -- --verbose` every 5 minutes by default using the same image as the primary app.

* Tune how often it runs using `nextcloud_cron_schedule`.

After applying Terraform you can confirm it’s running:

```bash
kubectl -n dropbloc get cronjob nextcloud-cron
kubectl -n dropbloc get jobs --sort-by=.metadata.creationTimestamp | tail -n 5
kubectl -n dropbloc logs job/<latest-nextcloud-cron-job>
```

---

# 🛠️ **6. Outputs**

After `apply`, Terraform prints:

```txt
nextcloud_lan_url    = http://192.168.1.50:30080
nextcloud_public_url = dropbloc.cloudbloc.io
```

---

# 🧪 **7. Tips & Best Practices**

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
