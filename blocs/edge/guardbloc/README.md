# GuardBloc (Edge) - AdGuard Home DNS

GuardBloc deploys AdGuard Home to an edge or homelab host with Docker Compose, using Terraform to run an idempotent SSH deployment.

It is intended for private LAN/Tailscale use:

- DNS filtering for trusted devices
- local DNS rewrites for homelab services
- persistent AdGuard config on the target host
- no public exposure

## What It Runs

- AdGuard Home container
- DNS over TCP and UDP on `DNS_PORT`, default `53`
- AdGuard setup/admin UI on `HTTP_PORT`, default `3000`
- persistent work/config data under `GUARDBLOC_ROOT`

## What Terraform Does

- connects to the edge host with SSH
- uploads the GuardBloc Compose file
- uploads and runs `deploy-guardbloc.sh`
- optionally installs Docker on Ubuntu/Debian if missing
- creates persistent folders under `guardbloc_root`
- writes `/opt/guardbloc/.env`
- runs `docker compose pull`
- runs `docker compose up -d`

Terraform never deletes DNS config data.

## Storage

`guardbloc_root` is the persistent host path for AdGuard work/config data. It defaults to `/var/lib/guardbloc`.

```text
/var/lib/guardbloc/
  conf/
  work/
```

## DNS Binding

GuardBloc requires the root module to pass `service_bind_ip`. Binding DNS to the LAN IP is usually safer than binding to `0.0.0.0`, because host services such as `systemd-resolved` may already listen on loopback port 53.

Use the edge host LAN IP when LAN clients should use GuardBloc for DNS:

```hcl
service_bind_ip = "192.168.1.50"
```

Use the host Tailscale IP only if you want tailnet-only DNS access.

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
  -var='ssh_user=ubuntu' \
  -var='service_bind_ip=192.168.1.50'
```

Open AdGuard setup/admin UI:

```text
http://192.168.1.50:3000
```

During first-run setup:

1. Create the AdGuard admin user.
2. Keep the DNS server listening on port `53`.
3. Keep the web UI on port `3000`, unless you also update `http_port`.
4. Add local DNS rewrites as needed, for example `app.example.internal -> 192.168.1.50`.

## Client Setup

Point trusted LAN clients or your router DHCP DNS setting to:

```text
192.168.1.50
```

For Tailscale clients, use the host Tailscale IP if GuardBloc is bound to that address.

## Operations

Start:

```bash
cd /opt/guardbloc
sudo docker compose up -d
```

Stop:

```bash
cd /opt/guardbloc
sudo docker compose down
```

Logs:

```bash
cd /opt/guardbloc
sudo docker compose logs -f
```

Upgrade:

```bash
terraform apply
```

## Security Notes

- Do not expose AdGuard DNS or the admin UI to the public internet.
- Keep access LAN/Tailscale only.
- Use a strong AdGuard admin password.
- Keep AdGuard config data out of git.
