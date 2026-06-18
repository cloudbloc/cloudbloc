# blocs/edge

This directory mirrors the GCP blocs but is configured for edge/homelab deployments.

Use-case
- Replace `blocs/gcp/<module>` with `blocs/edge/<module>` in example or environment module sources to target edge/homelab.
- `streambloc` provides a Docker Compose based Jellyfin media server for Tiny/homelab streaming.
- `guardbloc` provides a Docker Compose based AdGuard Home DNS/filtering service for private LAN or tailnet use.
- `homebloc` provides a Docker Compose based Home Assistant service for private LAN or tailnet use.

Examples:
- Relative:
  `source = "../../blocs/edge/<module>"`
- GitHub:
  `source = "github.com/cloudbloc/cloudbloc//blocs/edge/<module>?ref=<tag>"`

Behavior
- Edge modules keep the same inputs/outputs as their GCP counterparts where possible to allow easy switching.
