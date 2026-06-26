# HomeBloc (Edge) - Home Assistant

HomeBloc deploys Home Assistant Container to an edge or homelab host with Docker Compose, using Terraform to run an idempotent SSH deployment.

It is intended for private LAN/Tailscale use:

- Home Assistant web UI
- local device and integration discovery through host networking
- persistent Home Assistant config on the target host
- no public exposure

## What It Runs

- Home Assistant container from `ghcr.io/home-assistant/home-assistant`
- host networking for discovery and local integrations
- Home Assistant web UI on `http_port`, default `8123`
- persistent config data under `HOMEBLOC_ROOT`

## What Terraform Does

- connects to the edge host with SSH
- uploads the HomeBloc Compose file
- uploads and runs `deploy-homebloc.sh`
- optionally installs Docker on Ubuntu/Debian if missing
- creates persistent folders under `homebloc_root`
- writes `/opt/homebloc/.env`
- bootstraps `configuration.yaml` and `automations.yaml` if they do not exist
- ensures `configuration.yaml` includes `automations.yaml` for the UI automation editor
- runs `docker compose pull`
- runs `docker compose up -d`

Terraform never deletes Home Assistant config data.

## Storage

`homebloc_root` is the persistent host path for Home Assistant config data. It defaults to `/var/lib/homebloc`.

```text
/var/lib/homebloc/
  config/
    configuration.yaml
    automations.yaml
```

## Networking

HomeBloc uses Docker host networking. This is intentional: Home Assistant discovery, mDNS, Bluetooth, and many LAN integrations work better with host networking than with narrow port publishing.

The default UI endpoint is:

```text
http://<host>:8123
```

If you change `http_port`, HomeBloc only sets the bootstrap HTTP port when `configuration.yaml` does not already exist. Existing Home Assistant config remains user-owned, but HomeBloc will add the standard `automation: !include automations.yaml` line when it is missing so UI-created automations are loaded.

## Deploy

Before applying, verify SSH and sudo from the Terraform runner:

```bash
ssh <ssh_user>@<host> 'echo ssh-ok'
ssh <ssh_user>@<host> 'sudo -n true && echo sudo-ok'
```

Then run Terraform from an example/root module:

```bash
terraform init
terraform apply \
  -var='host=192.168.1.50' \
  -var='ssh_user=ubuntu'
```

Open Home Assistant:

```text
http://192.168.1.50:8123
```

Complete the Home Assistant first-run setup in the UI.

## Operations

Start:

```bash
cd /opt/homebloc
sudo docker compose up -d
```

Stop:

```bash
cd /opt/homebloc
sudo docker compose down
```

Logs:

```bash
cd /opt/homebloc
sudo docker compose logs -f
```

Upgrade:

```bash
terraform apply
```

## Security Notes

- Do not expose Home Assistant directly to the public internet.
- Keep access LAN/Tailscale only unless you intentionally add a secured reverse proxy.
- Use a strong Home Assistant account password.
- Keep Home Assistant config and tokens out of git.
