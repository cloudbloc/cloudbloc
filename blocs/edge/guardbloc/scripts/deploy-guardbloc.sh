#!/usr/bin/env sh
set -eu

REMOTE_ROOT="${REMOTE_ROOT:-/opt/guardbloc}"
GUARDBLOC_ROOT="${GUARDBLOC_ROOT:-/var/lib/guardbloc}"
SERVICE_BIND_IP="${SERVICE_BIND_IP:-127.0.0.1}"
DNS_PORT="${DNS_PORT:-53}"
HTTP_PORT="${HTTP_PORT:-3000}"
ADGUARD_VERSION="${ADGUARD_VERSION:-latest}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"

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

install_files() {
  mkdir -p "$REMOTE_ROOT"
  cp /tmp/cloudbloc-guardbloc/docker-compose.yml "$REMOTE_ROOT/docker-compose.yml"

  cat >"$REMOTE_ROOT/.env" <<EOF
COMPOSE_PROJECT_NAME=guardbloc
SERVICE_BIND_IP=$SERVICE_BIND_IP
DNS_PORT=$DNS_PORT
HTTP_PORT=$HTTP_PORT
ADGUARD_VERSION=$ADGUARD_VERSION
GUARDBLOC_ROOT=$GUARDBLOC_ROOT
EOF
}

create_storage() {
  mkdir -p "$GUARDBLOC_ROOT/work" "$GUARDBLOC_ROOT/conf"
}

start_stack() {
  cd "$REMOTE_ROOT"
  docker compose -f docker-compose.yml pull
  docker compose -f docker-compose.yml up -d
}

require_docker
install_files
create_storage
start_stack

docker compose -f "$REMOTE_ROOT/docker-compose.yml" ps
