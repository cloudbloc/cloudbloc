# StreamBloc (Edge) - Jellyfin + Arr Media Stack

StreamBloc provides a self-hosted streaming/media setup for a homelab Tiny using Jellyfin and the Arr stack.

It is intentionally private-network only:

- no public exposure
- no reverse proxy
- no Traefik
- no Kubernetes
- secure remote access is expected through Tailscale

## What It Runs

- Jellyfin media server
- Sonarr for TV library management
- Radarr for movie library management
- Prowlarr for indexer management
- Bazarr for subtitles
- qBittorrent for downloads
- persistent app config under `STREAMBLOC_ROOT`
- media and downloads under `MEDIA_ROOT`
- optional Intel QuickSync / VAAPI hardware transcoding through `docker-compose.hwaccel.yml`

## What You Must Provide

- A Tiny or homelab host reachable by SSH.
- An SSH user that can run `sudo` without an interactive password prompt.
- Persistent storage mounted on the host. `storage_root` defaults to `/mnt/dropbloc` for the existing Tiny, but can be changed.
- Media folders under `MEDIA_ROOT`, which defaults to `storage_root/streambloc-media`.
- Optional Intel iGPU with `/dev/dri` for QuickSync transcoding.
- Bind IPs for services. Use `0.0.0.0` for LAN + Tailscale access, or the Tiny Tailscale IP for tailnet-only access.
- Tailscale or another private network path for remote access.

## Assumptions

- StreamBloc runs directly on a Tiny with Docker Compose, not in Kubernetes.
- Terraform deploys the stack by SSHing into the Tiny, uploading Compose files, and running `scripts/deploy-streambloc.sh`.
- The deploy script can install Docker on apt-based systems when `install_docker = true`.
- The deploy script refuses to write under `storage_root` unless it is an active mount point when `require_storage_mount = true`.
- Services are reachable only on the bind IPs and ports configured in `.env`.
- Remote access is handled by Tailscale, not by this bloc.
- `MEDIA_ROOT` is backed by persistent storage and is managed outside Compose.
- `STREAMBLOC_ROOT` is backed by persistent storage for app config and cache.
- Downloads and final media live under the same `MEDIA_ROOT` filesystem so moves and hardlinks work correctly.
- Intel QuickSync is optional and only enabled when the host exposes `/dev/dri`.

## Folder Layout

Recommended host layout:

```text
storage_root/
  streambloc/
    jellyfin/config/
    jellyfin/cache/
    sonarr/config/
    radarr/config/
    prowlarr/config/
    bazarr/config/
    qbittorrent/config/
  streambloc-media/
    media/
      movies/
      tv/
      music/
      photos/
    downloads/
      complete/
      incomplete/
      torrents/
      usenet/
```

With the default `storage_root = "/mnt/dropbloc"`, that expands to `/mnt/dropbloc/streambloc` and `/mnt/dropbloc/streambloc-media`.

Inside the containers, `MEDIA_ROOT` is mounted as `/data`, so configure apps with these paths:

```text
Jellyfin movies: /data/media/movies
Jellyfin TV:     /data/media/tv
Radarr root:     /data/media/movies
Sonarr root:     /data/media/tv
qBittorrent:     /data/downloads/torrents
```

Do not store StreamBloc media inside `/mnt/dropbloc/nextcloud-data`. That is Nextcloud's internal data tree. If Nextcloud needs to see media later, expose `/mnt/dropbloc/streambloc-media` to Nextcloud as external storage or run a targeted file scan.

## Terraform Deploy

From an example/root module, pass the Tiny host and storage settings:

```hcl
module "streambloc" {
  source = "github.com/cloudbloc/cloudbloc//blocs/edge/streambloc?ref=edge-streambloc-v0.1.0"
  # source = "../../../blocs/edge/streambloc"

  tiny_host = "10.0.0.187"
  tiny_user = "yprk"

  storage_root = "/mnt/dropbloc"
}
```

Before applying, verify SSH, sudo, and the SSD mount from the Terraform runner:

```bash
ssh yprk@10.0.0.187 'echo ssh-ok'
ssh yprk@10.0.0.187 'sudo -n true && echo sudo-ok'
ssh yprk@10.0.0.187 'mountpoint -q /mnt/dropbloc && echo mounted'
```

Then run:

```bash
terraform init
terraform apply
```

Terraform writes the runtime Compose project to `remote_root`, which defaults to `/opt/streambloc`.

## Manual Recovery

If Terraform is unavailable, you can still run the stack manually from the installed `remote_root` on the Tiny:

```bash
cd /opt/streambloc
sudo docker compose up -d
sudo docker compose logs -f
```

If `/dev/dri` exists and you want Intel QuickSync support, include the hardware acceleration override:

```bash
sudo docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
```

Open the services:

```text
Jellyfin:    http://10.0.0.187:8096 or http://<tiny-tailscale-ip>:8096
Sonarr:      http://10.0.0.187:8989 or http://<tiny-tailscale-ip>:8989
Radarr:      http://10.0.0.187:7878 or http://<tiny-tailscale-ip>:7878
Prowlarr:    http://10.0.0.187:9696 or http://<tiny-tailscale-ip>:9696
Bazarr:      http://10.0.0.187:6767 or http://<tiny-tailscale-ip>:6767
qBittorrent: http://10.0.0.187:8080 or http://<tiny-tailscale-ip>:8080
```

## Jellyfin Setup

During first-run setup:

1. Create the admin user.
2. Add libraries:
   - Movies: `/data/media/movies`
   - TV Shows: `/data/media/tv`
   - Music: `/data/media/music`
   - Photos: `/data/media/photos`
3. Keep remote access disabled in Jellyfin unless you intentionally route through Tailscale.
4. If the Tiny has Intel QuickSync:
   - open Dashboard -> Playback -> Transcoding
   - enable hardware acceleration with VAAPI or Intel QSV
   - use `/dev/dri/renderD128` when prompted

## Arr First-Run Wiring

Use the web UIs to connect the apps after the containers are running:

1. In qBittorrent, set the default save path to `/data/downloads/torrents`.
2. In Prowlarr, add your legal indexers, then add Sonarr and Radarr under Settings -> Apps.
3. In Sonarr, set the root folder to `/data/media/tv` and add qBittorrent as the download client.
4. In Radarr, set the root folder to `/data/media/movies` and add qBittorrent as the download client.
5. In Bazarr, connect Sonarr and Radarr, then use `/data/media/tv` and `/data/media/movies`.

## TV And Client Setup

Use official Jellyfin clients where possible:

- Android TV / Google TV: Jellyfin app from Play Store
- Apple TV / iOS: Swiftfin or Jellyfin app
- Roku: Jellyfin channel
- Fire TV: Jellyfin app
- Web browser: `http://10.0.0.187:8096`

For remote viewing, connect the client device to the tailnet first, then use the Tiny Tailscale IP or MagicDNS name.

## Operations

Start:

```bash
cd /opt/streambloc
sudo docker compose up -d
```

Stop:

```bash
cd /opt/streambloc
sudo docker compose down
```

Logs:

```bash
cd /opt/streambloc
sudo docker compose logs -f
```

Start with Intel QuickSync override:

```bash
cd /opt/streambloc
sudo docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
```

Upgrade:

```bash
terraform apply
```

## Security Notes

- Do not port-forward these services from the router.
- Do not expose Jellyfin, Arr apps, or qBittorrent directly to the public internet.
- Keep remote access behind Tailscale.
- Keep app credentials and API keys out of git.
- Keep `.env` local; commit only `.env.example`.
- Use download/indexer integrations only for media you have the right to access.
