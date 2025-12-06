# blocs/gcp

This directory contains Terraform modules and stacks targeting Google Cloud Platform.

Conventions
- Module source paths for GCP use `blocs/gcp/<module>`.
- Do not change module variable names or outputs; pass values from caller modules.

How to use a GCP bloc
- GitHub:
  `source = "github.com/cloudbloc/cloudbloc//blocs/gcp/<bloc>?ref=<tag>"`
- Relative local:
  `source = "../../blocs/gcp/<bloc>"`

Examples:
- examples/gcp/* contain example deployments that reference `blocs/gcp/*`.
- To test an example, run terraform init/plan from the example directory (not the module directory).
