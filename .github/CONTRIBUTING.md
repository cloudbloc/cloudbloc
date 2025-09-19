# Contributing to Cloudbloc

Thanks for helping build SaaS-as-Code!

## Ground rules
- Use Conventional Commits with bloc scope: e.g. `feat(searchbloc): ...`, `fix(obsbloc): ...`
- Run `terraform fmt` / `terraform validate` before pushing
- Update bloc READMEs when inputs/outputs change
- Small PRs > large PRs

## Setup
- Terraform ≥ 1.5, `gcloud auth login`
- A GKE Autopilot cluster (see examples)

## Pull requests
- Open against `main`
- Include a short rationale + testing notes
- If your change affects users, add docs/changelog entry

## Releases
- Managed by release-please (manifest). Tags like `searchbloc-vX.Y.Z` are created automatically.
