# SPEC: hetzner-clawbot (Terragrunt for Clawbot hosts)

## Purpose
Provision and manage Hetzner Cloud server(s) that will run "clawbot" workloads.

This repository contains:
- Terragrunt live stacks under `/live`
- Terraform modules under `/modules`

The focus is infrastructure provisioning first. Application deployment/bootstrap comes later.

---

## How Codex is invoked

Codex will be invoked from inside the repository root.

Treat this SPEC as the authoritative source for:
- repo layout
- naming conventions
- architecture assumptions
- milestone definitions
- what “done” means
- what must not change without asking

Codex must always propose minimal diffs and include exact commands to validate changes.

---

## Non-goals (for now)

- Full CI/CD pipeline
- Kubernetes
- Multi-cloud abstractions
- Complex networking (VPC peering, VPN, etc.)
- Monitoring stacks or unrelated services

---

## Target environment

- Operator machine: Ubuntu Linux
- IaC tooling: Terraform + Terragrunt
- Provider: Hetzner Cloud (hcloud)

---

## Required tooling

- terraform
- terragrunt

---

## Inputs / Secrets

- `HCLOUD_TOKEN` must be provided via environment variable.
- SSH public keys must already exist in Hetzner Cloud and be referenced by name.
- No secrets may ever be committed to this repository.

---

## Region / Location Conventions

This repository uses:

- Folder label: `us-east`
- Terraform variable: `location` (real Hetzner location string)

Important:

Hetzner does not literally have a region called "us-east".
Actual location values may include:
- `ash` (Ashburn, VA)
- `hil` (Hillsboro, OR)
- `fsn1`, `nbg1`, `hel1` (EU)

We use `us-east` only as a human folder label.
The real Hetzner `location` must be configurable via Terraform input.

---

## Architecture Assumption

Default server type is `cpx22`.

- `cpx22` is x86_64 (amd64).
- All provisioned servers must be treated as `linux/amd64`.

Any container images or binaries deployed to these servers must:
- be built for `amd64`, or
- be multi-architecture images that include `amd64`.

ARM (aarch64) should not be assumed.

---

## Default Server Type

Unless explicitly overridden, the default:

```
server_type = "cpx22"
```

If Hetzner changes instance offerings in the future, this default should be updated in one centralized location (preferably a shared Terragrunt defaults file).

---

## Repository Layout (Desired)

```
hetzner-clawbot/
  live/
    prod/
      us-east/
        clawbot/
          terragrunt.hcl
    stage/
      us-east/
        clawbot/
          terragrunt.hcl
  modules/
    clawbot_server/
      main.tf
      variables.tf
      outputs.tf
  docs/
    quickstart.md
  SPEC.md
  AGENTS.md
```

---

## Naming Conventions

- Hetzner server name: `clawbot-<env>-<index>`
- Environment folders: `prod`, `stage`, `dev`
- Region folders: `us-east`
- Terraform variable for real Hetzner location: `location`

---

## Module Design Guidelines

- Modules must not define Terraform backend blocks.
- Terragrunt is responsible for backend/state configuration.
- Variables must be explicitly typed.
- Avoid clever logic; prefer clarity.
- Labels must include:
  - `env`
  - `role = "clawbot"`

---

## Required Module Outputs

Each clawbot server module must output:

- server id
- server name
- public ipv4 address
- public ipv6 address (if available)

---

## State & Safety

- Remote state (S3-compatible or similar) is preferred long-term.
- Local state is acceptable initially but must be clearly documented.
- No firewall rules should default to 0.0.0.0/0 unless explicitly temporary and documented.

---

# Milestone 1: Provision One Server

## Deliverables

1) Terraform module: `modules/clawbot_server`

Must provision:

- 1 `hcloud_server`
- image: Ubuntu LTS (22.04 or 24.04)
- server_type: configurable (default cpx22)
- location: configurable
- ssh_keys: configurable list of key names
- labels: env + role=clawbot

2) Terragrunt stack at:

```
live/prod/us-east/clawbot/terragrunt.hcl
```

3) Documentation:

`docs/quickstart.md` must include:

- export HCLOUD_TOKEN
- terragrunt init
- terragrunt plan
- terragrunt apply
- terragrunt destroy

---

## Acceptance Criteria

- `terragrunt plan` succeeds with:
  - HCLOUD_TOKEN set
  - valid SSH key name(s)
- `terragrunt apply` successfully creates the server
- Output displays public IPv4
- `terragrunt destroy` cleanly removes all resources

---

# Milestone 2: Baseline Security

After Milestone 1 works end-to-end:

- Add hcloud firewall resource
- Allow inbound SSH (22) from configurable CIDR allowlist
- Allow outbound all
- No broad open access by default

Optional (later):
- Basic SSH hardening via cloud-init

---

# Milestone 3: Clawbot Bootstrap

Add cloud-init configuration that:

- Creates non-root user(s)
- Sets SSH hardening defaults
- Installs Docker or required system packages
- Prepares directory layout for clawbot services

---

## How Codex Must Operate

- Always propose minimal diffs.
- Never introduce new tools without explanation.
- Never modify state backend configuration without explicit request.
- Always include validation commands:
  - `terraform fmt -recursive`
  - `terragrunt plan`
- Do not perform destructive actions unless explicitly requested.

