# StreamBloc Edge Example

This example deploys StreamBloc to a Tiny over SSH, using Terraform to run an idempotent Docker Compose deployment script.

It is private-network only. Use Tailscale for secure remote access.

The example calls StreamBloc by tag:

```hcl
source = "github.com/cloudbloc/cloudbloc//blocs/edge/streambloc?ref=edge-streambloc-v0.1.0"
```

For local development, switch the source to:

```hcl
source = "../../../blocs/edge/streambloc"
```

## What Terraform Does

- connects to the Tiny with SSH
- uploads the StreamBloc Compose files
- uploads and runs `deploy-streambloc.sh`
- optionally installs Docker on Ubuntu/Debian if missing
- creates persistent folders under `storage_root`
- writes `/opt/streambloc/.env`
- runs `docker compose pull`
- runs `docker compose up -d`

Terraform never deletes media.

## Storage

`storage_root` is the persistent SSD mount root. It defaults to `/mnt/dropbloc` because DropBloc already uses `/mnt/dropbloc/nextcloud-data`, but you can change it.

```text
storage_root=/mnt/dropbloc
streambloc_root=storage_root/streambloc
media_root=storage_root/streambloc-media
```

To use a different SSD mount:

```bash
terraform apply -var='storage_root=/mnt/ssd'
```

Do not put StreamBloc media directly inside `/mnt/dropbloc/nextcloud-data`.

## Deploy

Make sure you can SSH to the Tiny first:

```bash
ssh yprk@10.0.0.187
```

Then deploy:

```bash
terraform init -reconfigure -backend-config=backend/prd.conf
terraform apply
```

To deploy over the Tiny Tailscale IP:

```bash
terraform apply -var='tiny_host=100.x.y.z'
```

If your SSH key is not in your agent:

```bash
terraform apply -var='ssh_private_key_path=~/.ssh/id_ed25519'
```

The SSH user must be able to run `sudo` without an interactive password prompt, because the script creates `/opt/streambloc`, writes under `storage_root`, and may install Docker.

## Service URLs

Open services on LAN or through the Tiny Tailscale IP:

```text
Jellyfin:    http://10.0.0.187:8096 or http://<tiny-tailscale-ip>:8096
Sonarr:      http://10.0.0.187:8989 or http://<tiny-tailscale-ip>:8989
Radarr:      http://10.0.0.187:7878 or http://<tiny-tailscale-ip>:7878
Prowlarr:    http://10.0.0.187:9696 or http://<tiny-tailscale-ip>:9696
Bazarr:      http://10.0.0.187:6767 or http://<tiny-tailscale-ip>:6767
qBittorrent: http://10.0.0.187:8080 or http://<tiny-tailscale-ip>:8080
```

Do not expose these services directly to the public internet.
