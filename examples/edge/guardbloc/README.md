# GuardBloc Edge Example

This example deploys GuardBloc to an edge host over SSH, using Terraform to run an idempotent Docker Compose deployment script.

It is private-network only. Use LAN/Tailscale for access.

The example calls GuardBloc by tag:

```hcl
source = "github.com/cloudbloc/cloudbloc//blocs/edge/guardbloc?ref=edge-guardbloc-v0.1.0"
```

For local development, switch the source to:

```hcl
source = "../../../blocs/edge/guardbloc"
```

## What Terraform Does

- connects to the edge host with SSH
- uploads the GuardBloc Compose file
- uploads and runs `deploy-guardbloc.sh`
- optionally installs Docker on Ubuntu/Debian if missing
- creates persistent folders under `guardbloc_root`
- writes `/opt/guardbloc/.env`
- runs `docker compose pull`
- runs `docker compose up -d`

Terraform never deletes AdGuard config data.

## Storage

`guardbloc_root` is the persistent host path for AdGuard work/config data. It defaults to `/var/lib/guardbloc`.

## Deploy

Make sure you can SSH to the edge host first:

```bash
ssh <ssh_user>@<host>
```

Verify sudo:

```bash
ssh <ssh_user>@<host> 'sudo -n true && echo sudo-ok'
```

Then deploy:

```bash
terraform init -reconfigure -backend-config=backend/prd.conf
terraform apply \
  -var='host=192.168.1.50' \
  -var='ssh_user=ubuntu' \
  -var='service_bind_ip=192.168.1.50'
```

If your SSH key is not in your agent:

```bash
terraform apply \
  -var='host=192.168.1.50' \
  -var='ssh_user=ubuntu' \
  -var='service_bind_ip=192.168.1.50' \
  -var='ssh_private_key_path=~/.ssh/id_ed25519'
```

## Service URLs

Open the setup/admin UI:

```text
http://192.168.1.50:3000
```

Use DNS from trusted clients:

```text
192.168.1.50:53/tcp
192.168.1.50:53/udp
```

Do not expose these services directly to the public internet.
