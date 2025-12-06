# blocs/edge

This directory mirrors the GCP blocs but is configured for edge/homelab deployments.

Use-case
- Replace `blocs/gcp/<module>` with `blocs/edge/<module>` in example or environment module sources to target edge/homelab.

Examples:
- Relative:
  `source = "../../blocs/edge/<module>"`
- GitHub:
  `source = "github.com/cloudbloc/cloudbloc//blocs/edge/<module>?ref=<tag>"`

Behavior
- Edge modules keep the same inputs/outputs as their GCP counterparts where possible to allow easy switching.
