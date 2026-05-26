#!/usr/bin/env sh
set -eu

REMOTE_ROOT="${REMOTE_ROOT:-/opt/streambloc}"
STORAGE_ROOT="${STORAGE_ROOT:-/mnt/dropbloc}"
STREAMBLOC_ROOT="${STREAMBLOC_ROOT:-$STORAGE_ROOT/streambloc}"
MEDIA_ROOT="${MEDIA_ROOT:-$STORAGE_ROOT/streambloc-media}"
TZ="${TZ:-America/New_York}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
BIND_IP="${BIND_IP:-0.0.0.0}"
JELLYFIN_PUBLIC_URL="${JELLYFIN_PUBLIC_URL:-http://127.0.0.1:8096}"
ENABLE_HWACCEL="${ENABLE_HWACCEL:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
REQUIRE_STORAGE_MOUNT="${REQUIRE_STORAGE_MOUNT:-true}"
VIDEO_GID="${VIDEO_GID:-44}"
RENDER_GID="${RENDER_GID:-109}"

require_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return
  fi

  if [ "$INSTALL_DOCKER" != "true" ]; then
    echo "Docker Compose is not available and INSTALL_DOCKER=false." >&2
    exit 1
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Automatic Docker install currently supports apt-based systems only." >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y docker.io docker-compose-plugin
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker
  fi
}

require_storage() {
  mkdir -p "$STORAGE_ROOT"

  if [ "$REQUIRE_STORAGE_MOUNT" != "true" ]; then
    return
  fi

  if ! mountpoint -q "$STORAGE_ROOT"; then
    echo "$STORAGE_ROOT is not an active mount point. Refusing to create media directories on the root filesystem." >&2
    echo "Mount the SSD first, or set require_storage_mount=false if this is intentional." >&2
    exit 1
  fi
}

install_files() {
  mkdir -p "$REMOTE_ROOT"
  cp /tmp/cloudbloc-streambloc/docker-compose.yml "$REMOTE_ROOT/docker-compose.yml"
  cp /tmp/cloudbloc-streambloc/docker-compose.hwaccel.yml "$REMOTE_ROOT/docker-compose.hwaccel.yml"

  cat >"$REMOTE_ROOT/.env" <<EOF
COMPOSE_PROJECT_NAME=streambloc
TZ=$TZ
PUID=$PUID
PGID=$PGID

JELLYFIN_BIND_IP=$BIND_IP
JELLYFIN_HTTP_PORT=8096
JELLYFIN_PUBLIC_URL=$JELLYFIN_PUBLIC_URL
JELLYFIN_VERSION=latest

SONARR_BIND_IP=$BIND_IP
SONARR_HTTP_PORT=8989
SONARR_VERSION=latest

RADARR_BIND_IP=$BIND_IP
RADARR_HTTP_PORT=7878
RADARR_VERSION=latest

PROWLARR_BIND_IP=$BIND_IP
PROWLARR_HTTP_PORT=9696
PROWLARR_VERSION=latest

BAZARR_BIND_IP=$BIND_IP
BAZARR_HTTP_PORT=6767
BAZARR_VERSION=latest

QBITTORRENT_BIND_IP=$BIND_IP
QBITTORRENT_HTTP_PORT=8080
QBITTORRENT_VERSION=latest

STREAMBLOC_ROOT=$STREAMBLOC_ROOT
MEDIA_ROOT=$MEDIA_ROOT

VIDEO_GID=$VIDEO_GID
RENDER_GID=$RENDER_GID
EOF
}

create_storage() {
  mkdir -p \
    "$STREAMBLOC_ROOT/jellyfin/config" \
    "$STREAMBLOC_ROOT/jellyfin/cache" \
    "$STREAMBLOC_ROOT/sonarr/config" \
    "$STREAMBLOC_ROOT/radarr/config" \
    "$STREAMBLOC_ROOT/prowlarr/config" \
    "$STREAMBLOC_ROOT/bazarr/config" \
    "$STREAMBLOC_ROOT/qbittorrent/config" \
    "$MEDIA_ROOT/media/movies" \
    "$MEDIA_ROOT/media/tv" \
    "$MEDIA_ROOT/media/music" \
    "$MEDIA_ROOT/media/photos" \
    "$MEDIA_ROOT/downloads/complete" \
    "$MEDIA_ROOT/downloads/incomplete" \
    "$MEDIA_ROOT/downloads/torrents" \
    "$MEDIA_ROOT/downloads/usenet"

  chown -R "$PUID:$PGID" "$STREAMBLOC_ROOT" "$MEDIA_ROOT"
}

start_stack() {
  cd "$REMOTE_ROOT"

  if [ "$ENABLE_HWACCEL" = "true" ] && [ -e /dev/dri ]; then
    docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml pull
    docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
  else
    docker compose -f docker-compose.yml pull
    docker compose -f docker-compose.yml up -d
  fi
}

require_docker
require_storage
install_files
create_storage
start_stack

docker compose -f "$REMOTE_ROOT/docker-compose.yml" ps
