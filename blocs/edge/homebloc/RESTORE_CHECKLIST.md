# HomeBloc Restore Checklist

Use this checklist to rebuild HomeBloc on a fresh edge host.

## What Compose Manages

- Home Assistant container.
- Restart policy `unless-stopped`.
- Host networking for Home Assistant discovery.
- Persistent Home Assistant config data under `HOMEBLOC_ROOT`.

## Manual Setup Required

- Install the edge host OS.
- Assign or reserve the edge host LAN IP.
- Make sure the Terraform runner can SSH to the edge host.
- Make sure the SSH user can run passwordless `sudo`.
- Run `terraform apply` from `examples/edge/homebloc` or another root module.
- Complete the Home Assistant first-run setup wizard.

## Missing Local Files

These should exist on the edge host but are not committed:

- `/opt/homebloc/.env`
- Home Assistant config data under `/var/lib/homebloc` by default

## Host-Level Dependencies

- Docker Engine.
- Docker Compose v2.
- Persistent host filesystem for `homebloc_root`.
- LAN firewall allowing UI `8123/tcp` from trusted clients.

## Rebuild Commands

From the Terraform runner, verify host prerequisites:

```bash
ssh <ssh_user>@<host> 'echo ssh-ok'
ssh <ssh_user>@<host> 'sudo -n true && echo sudo-ok'
```

Then deploy:

```bash
cd examples/edge/homebloc
terraform init -reconfigure -backend-config=backend/prd.conf
terraform apply \
  -var='host=192.168.1.50' \
  -var='ssh_user=ubuntu'
```

Terraform recreates:

```text
/opt/homebloc
/var/lib/homebloc
```

If Terraform is unavailable but `/opt/homebloc` already exists, recover manually on the edge host:

```bash
cd /opt/homebloc
sudo docker compose up -d
```

Open:

```text
Home Assistant UI: http://192.168.1.50:8123
```

## Restore Existing Data

If restoring an existing instance, restore this before `docker compose up -d`:

```text
/var/lib/homebloc
```
