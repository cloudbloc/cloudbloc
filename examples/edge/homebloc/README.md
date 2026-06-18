# HomeBloc Edge Example

This example deploys HomeBloc to an edge host over SSH, using Terraform to run an idempotent Docker Compose deployment script.

It is private-network only. Use LAN/Tailscale for access.

For local development, the example calls HomeBloc by relative source:

```hcl
source = "../../../blocs/edge/homebloc"
```

After HomeBloc is released, switch to a pinned GitHub source:

```hcl
source = "github.com/cloudbloc/cloudbloc//blocs/edge/homebloc?ref=edge-homebloc-v0.1.0"
```

## What Terraform Does

- connects to the edge host with SSH
- uploads the HomeBloc Compose file
- uploads and runs `deploy-homebloc.sh`
- optionally installs Docker on Ubuntu/Debian if missing
- creates persistent folders under `homebloc_root`
- writes `/opt/homebloc/.env`
- bootstraps `configuration.yaml` only if it does not exist
- runs `docker compose pull`
- runs `docker compose up -d`

Terraform never deletes Home Assistant config data.

## Storage

`homebloc_root` is the persistent host path for Home Assistant config data. It defaults to `/var/lib/homebloc`.

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
  -var='ssh_user=ubuntu'
```

If your SSH key is not in your agent:

```bash
terraform apply \
  -var='host=192.168.1.50' \
  -var='ssh_user=ubuntu' \
  -var='ssh_private_key_path=~/.ssh/id_ed25519'
```

## Service URLs

Open Home Assistant:

```text
http://192.168.1.50:8123
```

Complete first-run setup in the Home Assistant UI.

Do not expose Home Assistant directly to the public internet.
