# Clawbot Quickstart

## Prerequisites

- Install `terragrunt`
- Export Hetzner token in your shell:
  - `export HCLOUD_TOKEN=<token>`

## Provision (prod)

```bash
cd live/prod/us-east/clawbot
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output
terragrunt destroy
```

## Provision (stage)

```bash
cd live/stage/us-east/clawbot
terragrunt init
terragrunt plan
terragrunt apply
terragrunt destroy
```

## Validation/formatting commands (repo-wide)

```bash
terraform fmt -recursive
```

## Notes

- Remote backend is not configured by default; state is local unless configured in Terragrunt.
- Firewall policy is least-privilege by default (`firewall_ssh_cidrs = []` means SSH is not publicly reachable until allowlist is set).
