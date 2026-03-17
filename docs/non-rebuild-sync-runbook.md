# Non-rebuild sync runbook

This runbook defines the operator-side path for shipping small tool or template changes without replacing the node.

## Why this exists

Right now, changes to bootstrap-installed tools and templates normally force a node replacement because they ride through `user_data`.

That is too expensive for small changes such as:

- a host-side CLI bugfix
- a template-library update
- a specialist guidance tweak

## Script

Use:

- [sync-node-assets.sh](/home/mcintosh/repos/hetzner-clawbot/scripts/sync-node-assets.sh)

## Scope

This script syncs:

- host-side tools into `/usr/local/bin/`
- agent-config templates into `/opt/clawbot/config/agent-config/`

It does not:

- rebuild the node
- change Terraform state
- restart services automatically
- replace the bootstrap path as the baseline provisioning mechanism

## Usage

```bash
scripts/sync-node-assets.sh tools
scripts/sync-node-assets.sh templates
scripts/sync-node-assets.sh all
scripts/sync-node-assets.sh tool clawbot-template-library
scripts/sync-node-assets.sh template specialists/qa.md
```

Optional overrides:

```bash
HOST=91.107.207.3 SSH_KEY=/home/mcintosh/.ssh/mcintosh-clawbot scripts/sync-node-assets.sh tools
```

## When to use it

Use the non-rebuild sync path for:

- host-side CLI updates
- template-library updates
- specialist guidance changes that live under `agent-config`

Do not use it for:

- baseline provisioning changes
- package/runtime install changes
- systemd/container wiring changes that still depend on bootstrap logic
- anything that should remain tied to an auditable rebuild milestone

## Recommended discipline

1. make the local change
2. commit it
3. use the narrowest sync possible
4. run the smallest validation that proves the change
5. if the change really belongs in baseline provisioning, still keep the bootstrap version current

## Examples

### Sync only the template library tool

```bash
scripts/sync-node-assets.sh tool clawbot-template-library
```

### Sync only the QA specialist guidance template

```bash
scripts/sync-node-assets.sh template specialists/qa.md
```

### Sync all host tools and templates

```bash
scripts/sync-node-assets.sh all
```

## Important constraint

This path is for operator-driven incremental sync.

It is not yet:

- a bot permission
- a queue action
- a generic remote execution system

Keep it operator-only for now.
