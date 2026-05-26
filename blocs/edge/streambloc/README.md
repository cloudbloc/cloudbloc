# StreamBloc (Edge) - Jellyfin Media Server

StreamBloc provides a simple self-hosted streaming/media setup for a homelab Tiny using Jellyfin.

It is intentionally local-network only:

- no public exposure
- no reverse proxy
- no Traefik
- no Kubernetes
- secure remote access is expected through AccessBloc/Tailscale

## What It Runs

- Jellyfin media server
- persistent config under `/srv/streambloc/jellyfin/config`
- persistent cache under `/srv/streambloc/jellyfin/cache`
- media mounted from `/srv/media`
- optional Intel QuickSync / VAAPI hardware transcoding through `docker-compose.hwaccel.yml`

Future services such as Sonarr, Radarr, Prowlarr, Bazarr, and qBittorrent are included only as commented Compose stubs.

## What You Must Provide

- A Tiny or homelab host with Docker and Docker Compose.
- Persistent storage mounted at `/srv/media`.
- Media folders under `/srv/media`.
- Optional Intel iGPU with `/dev/dri` for QuickSync transcoding.
- LAN IP for Jellyfin binding, for example `10.0.0.187`.
- AccessBloc/Tailscale or another private network path for remote access.

## Assumptions

- StreamBloc runs directly on a Tiny with Docker Compose, not in Kubernetes.
- Jellyfin is reachable only on the LAN IP and port configured in `.env`.
- Remote access is handled by AccessBloc/Tailscale, not by this bloc.
- `/srv/media` is backed by persistent storage and is managed outside Compose.
- `/srv/streambloc` is backed by persistent storage for Jellyfin config and cache.
- Intel QuickSync is optional and only enabled when the host exposes `/dev/dri`.
- Media acquisition/automation services are future additions, not part of the initial deployment.

## Folder Layout

Recommended host layout:

```text
/srv/media/
  movies/
  tv/
  music/
  photos/
  downloads/

/srv/streambloc/
  jellyfin/
    config/
    cache/
```

## Manual Setup

1. Install Docker and Docker Compose on the Tiny.

2. Create the host folders:

   ```bash
   sudo mkdir -p /srv/media/movies /srv/media/tv /srv/media/music /srv/media/photos /srv/media/downloads
   sudo mkdir -p /srv/streambloc/jellyfin/config /srv/streambloc/jellyfin/cache
   ```

3. Set ownership for the user that will run Docker Compose:

   ```bash
   sudo chown -R "$USER:$USER" /srv/streambloc
   ```

   Keep `/srv/media` ownership aligned with how media is copied onto the Tiny.

4. Confirm QuickSync device availability if you want hardware transcoding:

   ```bash
   ls -la /dev/dri
   getent group video
   getent group render
   ```

5. Copy `.env.example` to `.env` and edit values:

   ```bash
   cp .env.example .env
   ```

6. Start Jellyfin:

   ```bash
   docker compose up -d
   ```

   If `/dev/dri` exists and you want Intel QuickSync support, include the hardware acceleration override:

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
   ```

7. Open Jellyfin on the LAN:

   ```text
   http://10.0.0.187:8096
   ```

## Jellyfin Setup

During first-run setup:

1. Create the admin user.
2. Add libraries:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
   - Music: `/media/music`
   - Photos: `/media/photos`
3. Keep remote access disabled in Jellyfin unless you intentionally route through AccessBloc/Tailscale.
4. If the Tiny has Intel QuickSync:
   - open Dashboard -> Playback -> Transcoding
   - enable hardware acceleration with VAAPI or Intel QSV
   - use `/dev/dri/renderD128` when prompted

## TV And Client Setup

Use official Jellyfin clients where possible:

- Android TV / Google TV: Jellyfin app from Play Store
- Apple TV / iOS: Swiftfin or Jellyfin app
- Roku: Jellyfin channel
- Fire TV: Jellyfin app
- Web browser: `http://10.0.0.187:8096`

For remote viewing, connect the client device to the tailnet first, then use the Tiny Tailscale IP or MagicDNS name provided by AccessBloc/Tailscale.

## Operations

Start:

```bash
docker compose up -d
```

Stop:

```bash
docker compose down
```

Logs:

```bash
docker compose logs -f jellyfin
```

Start with Intel QuickSync override:

```bash
docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
```

Upgrade:

```bash
docker compose pull
docker compose up -d
```

## Security Notes

- Do not port-forward Jellyfin from the router.
- Do not expose Jellyfin directly to the public internet.
- Keep remote access behind AccessBloc/Tailscale.
- Keep Jellyfin admin credentials out of git.
- Keep `.env` local; commit only `.env.example`.
