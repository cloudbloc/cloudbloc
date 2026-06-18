#!/usr/bin/env sh
set -eu

REMOTE_ROOT="${REMOTE_ROOT:-/opt/homebloc}"
HOMEBLOC_ROOT="${HOMEBLOC_ROOT:-/var/lib/homebloc}"
HTTP_PORT="${HTTP_PORT:-8123}"
TZ="${TZ:-UTC}"
HOME_ASSISTANT_VERSION="${HOME_ASSISTANT_VERSION:-stable}"
HOME_ASSISTANT_PRIVILEGED="${HOME_ASSISTANT_PRIVILEGED:-true}"
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
  cp /tmp/cloudbloc-homebloc/docker-compose.yml "$REMOTE_ROOT/docker-compose.yml"

  cat >"$REMOTE_ROOT/.env" <<EOF
COMPOSE_PROJECT_NAME=homebloc
HOME_ASSISTANT_VERSION=$HOME_ASSISTANT_VERSION
HOME_ASSISTANT_PRIVILEGED=$HOME_ASSISTANT_PRIVILEGED
HOMEBLOC_ROOT=$HOMEBLOC_ROOT
HTTP_PORT=$HTTP_PORT
TZ=$TZ
EOF
}

create_storage() {
  mkdir -p "$HOMEBLOC_ROOT/config"

  if [ ! -f "$HOMEBLOC_ROOT/config/configuration.yaml" ]; then
    cat >"$HOMEBLOC_ROOT/config/configuration.yaml" <<EOF
# Managed bootstrap file created by HomeBloc.
# Home Assistant will extend this config through the UI and integrations.
default_config:

http:
  server_port: $HTTP_PORT
EOF
  fi
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
