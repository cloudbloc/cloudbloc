# GuardBloc Restore Checklist

Use this checklist to rebuild GuardBloc on a fresh edge host.

## What Compose Manages

- AdGuard Home container.
- Restart policy `unless-stopped`.
- Private-network-bound DNS and admin UI ports.
- Persistent AdGuard work/config data under `GUARDBLOC_ROOT`.

## Manual Setup Required

- Install the edge host OS.
- Assign or reserve the edge host LAN IP.
- Make sure the Terraform runner can SSH to the edge host.
- Make sure the SSH user can run passwordless `sudo`.
- Run `terraform apply` from `examples/edge/guardbloc` or another root module.
- Complete the AdGuard first-run setup wizard.
- Configure clients/router DHCP to use the edge host IP as DNS.

## Missing Local Files

These should exist on the edge host but are not committed:

- `/opt/guardbloc/.env`
- AdGuard config/work data under `/var/lib/guardbloc` by default

## Host-Level Dependencies

- Docker Engine.
- Docker Compose v2.
- Persistent host filesystem for `guardbloc_root`.
- LAN firewall allowing DNS `53/tcp`, `53/udp`, and UI `3000/tcp` from trusted clients.

## Rebuild Commands

From the Terraform runner, verify host prerequisites:

```bash
ssh <ssh_user>@<host> 'echo ssh-ok'
ssh <ssh_user>@<host> 'sudo -n true && echo sudo-ok'
```

Then deploy:

```bash
cd examples/edge/guardbloc
terraform init -reconfigure -backend-config=backend/prd.conf
terraform apply \
  -var='host=192.168.1.50' \
  -var='ssh_user=ubuntu' \
  -var='service_bind_ip=192.168.1.50'
```

Terraform recreates:

```text
/opt/guardbloc
/var/lib/guardbloc
```

If Terraform is unavailable but `/opt/guardbloc` already exists, recover manually on the edge host:

```bash
cd /opt/guardbloc
sudo docker compose up -d
```

Open:

```text
AdGuard UI: http://192.168.1.50:3000
DNS:        192.168.1.50:53/tcp and 192.168.1.50:53/udp
```

## Restore Existing Data

If restoring an existing instance, restore this before `docker compose up -d`:

```text
/var/lib/guardbloc
```
