# StreamBloc Restore Checklist

Use this checklist to rebuild StreamBloc on a fresh Tiny.

## What Compose Manages

- Jellyfin container.
- Restart policy `unless-stopped`.
- LAN-bound Jellyfin HTTP port.
- Persistent Jellyfin config volume.
- Persistent Jellyfin cache volume.
- Read-only media mount from `/srv/media`.
- Optional Intel QuickSync device mount from `/dev/dri` through `docker-compose.hwaccel.yml`.

## Manual Setup Required

- Install the Tiny OS.
- Assign or reserve the Tiny LAN IP.
- Install Docker and Docker Compose.
- Mount persistent media storage at `/srv/media`.
- Create StreamBloc state directories under `/srv/streambloc`.
- Copy media into `/srv/media`.
- Configure `.env` from `.env.example`.
- Configure Jellyfin first-run admin user and libraries.
- Configure Intel QuickSync in Jellyfin if available.
- Configure AccessBloc/Tailscale separately for secure remote access.

## Missing Local Files

These should exist on the Tiny but are not committed:

- `.env`
- Jellyfin config database under `/srv/streambloc/jellyfin/config`
- Jellyfin cache under `/srv/streambloc/jellyfin/cache`
- media files under `/srv/media`

## Host-Level Dependencies

- Docker Engine.
- Docker Compose v2.
- Persistent filesystem mounted at `/srv/media`.
- Optional Intel iGPU with `/dev/dri`.
- LAN firewall allowing the chosen Jellyfin port from local clients.

## Rebuild Commands

Install Docker using your preferred OS package flow, then:

```bash
sudo mkdir -p /srv/media/movies /srv/media/tv /srv/media/music /srv/media/photos /srv/media/downloads
sudo mkdir -p /srv/streambloc/jellyfin/config /srv/streambloc/jellyfin/cache
sudo chown -R "$USER:$USER" /srv/streambloc
```

From the StreamBloc directory:

```bash
cp .env.example .env
docker compose up -d
docker compose logs -f jellyfin
```

If restoring on a Tiny with Intel QuickSync:

```bash
docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
```

Open:

```text
http://10.0.0.187:8096
```

## Restore Existing Jellyfin Data

If restoring an existing instance, restore these before `docker compose up -d`:

```text
/srv/streambloc/jellyfin/config
/srv/media
```

The cache directory can usually be rebuilt:

```text
/srv/streambloc/jellyfin/cache
```

## TODOs To Automate Later

- Add an install script for Docker and Compose.
- Add a preflight script that checks `/srv/media`, `/srv/streambloc`, `/dev/dri`, and LAN binding.
- Add optional systemd unit for Compose lifecycle.
- Add backup/restore helper for Jellyfin config.
- Add optional Sonarr/Radarr/Prowlarr/Bazarr/qBittorrent profiles after the Jellyfin-only baseline is stable.
- Add Kubernetes version only after Compose version is proven on the Tiny.
