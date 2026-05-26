# StreamBloc Edge Example

This example shows how to run StreamBloc on a Tiny with Docker Compose.

It is local-network only. Use AccessBloc/Tailscale for secure remote access.

## Files

- `docker-compose.yml` references the reusable StreamBloc compose file.
- `.env.example` provides deployment values for a Tiny.

## Deploy

```bash
cp .env.example .env
docker compose up -d
docker compose logs -f jellyfin
```

For Intel QuickSync hardware transcoding:

```bash
docker compose -f docker-compose.yml -f docker-compose.hwaccel.yml up -d
```

Open Jellyfin:

```text
http://10.0.0.187:8096
```

Do not expose this service directly to the public internet.
