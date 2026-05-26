# StreamBloc Restore Checklist

Use this checklist to rebuild StreamBloc on a fresh Tiny.

## What Compose Manages

- Jellyfin, Sonarr, Radarr, Prowlarr, Bazarr, and qBittorrent containers.
- Restart policy `unless-stopped`.
- Private-network-bound service ports.
- Persistent app config under `STREAMBLOC_ROOT`.
- Shared `/data` mount from `MEDIA_ROOT`.
- Optional Intel QuickSync device mount from `/dev/dri` through `docker-compose.hwaccel.yml`.

## Manual Setup Required

- Install the Tiny OS.
- Assign or reserve the Tiny LAN IP.
- Install Docker and Docker Compose, or keep `install_docker = true` and let the deploy script install them on apt-based systems.
- Mount the persistent SSD at `storage_root`. The current default is `/mnt/dropbloc`.
- Make sure the Terraform runner can SSH to the Tiny.
- Make sure the SSH user can run passwordless `sudo`.
- Run `terraform apply` from `examples/edge/streambloc` or another root module.
- Configure Jellyfin first-run admin user and libraries.
- Wire Prowlarr, Sonarr, Radarr, Bazarr, and qBittorrent through their web UIs.
- Configure Intel QuickSync in Jellyfin if available.
- Use Tailscale separately for secure remote access.

## Missing Local Files

These should exist on the Tiny but are not committed:

- `/opt/streambloc/.env`
- app config under `storage_root/streambloc`
- media files under `storage_root/streambloc-media`

## Host-Level Dependencies

- Docker Engine.
- Docker Compose v2.
- Persistent filesystem mounted at `storage_root`.
- Optional Intel iGPU with `/dev/dri`.
- LAN firewall allowing chosen service ports from trusted private clients.

## Rebuild Commands

From the Terraform runner, verify host prerequisites:

```bash
ssh yprk@10.0.0.187 'echo ssh-ok'
ssh yprk@10.0.0.187 'sudo -n true && echo sudo-ok'
ssh yprk@10.0.0.187 'mountpoint -q /mnt/dropbloc && echo mounted'
```

Then deploy:

```bash
cd examples/edge/streambloc
terraform init -reconfigure -backend-config=backend/prd.conf
terraform apply
```

Terraform recreates:

```text
/opt/streambloc
storage_root/streambloc
storage_root/streambloc-media
```

If Terraform is unavailable but `/opt/streambloc` already exists, recover manually on the Tiny:

```bash
cd /opt/streambloc
sudo docker compose up -d
```

Open:

```text
Jellyfin:    http://10.0.0.187:8096 or http://<tiny-tailscale-ip>:8096
Sonarr:      http://10.0.0.187:8989 or http://<tiny-tailscale-ip>:8989
Radarr:      http://10.0.0.187:7878 or http://<tiny-tailscale-ip>:7878
Prowlarr:    http://10.0.0.187:9696 or http://<tiny-tailscale-ip>:9696
Bazarr:      http://10.0.0.187:6767 or http://<tiny-tailscale-ip>:6767
qBittorrent: http://10.0.0.187:8080 or http://<tiny-tailscale-ip>:8080
```

## Restore Existing Data

If restoring an existing instance, restore these before `docker compose up -d`:

```text
/mnt/dropbloc/streambloc
/mnt/dropbloc/streambloc-media
```

Jellyfin cache can usually be rebuilt:

```text
/mnt/dropbloc/streambloc/jellyfin/cache
```
