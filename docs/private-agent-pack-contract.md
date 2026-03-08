# Private Agent Pack Contract

## Purpose

This document defines how agent identity files move out of the public
infrastructure repo and into a pinned private agent-pack repo.

The public repo should own:

- infrastructure
- bootstrap logic
- runtime wiring
- contracts and validation rules

The private repo should own:

- `SOUL.md`
- `AGENT.md`
- `MEMORY.md`
- private skill definitions
- any private prompt/persona material that gives the agents their real identity

## Top-level rule

The public repo must not remain the source of truth for live agent identity.

The fallback prompt templates in `bootstrap-node-runner.sh` are transitional
bootstrap safety nets only. The target state is that production uses a pinned
private agent-pack export.

## Recommended private repo structure

```text
agents/
  bob/
    SOUL.md
    AGENT.md
    MEMORY.md
    SKILLS/
  stacks/
    SOUL.md
    AGENT.md
    MEMORY.md
    SKILLS/
  jennifer/
    SOUL.md
    AGENT.md
    MEMORY.md
    SKILLS/
  steve/
    SOUL.md
    AGENT.md
    MEMORY.md
    SKILLS/
  number5/
    SOUL.md
    AGENT.md
    MEMORY.md
    SKILLS/
scripts/
  render-agent-config.sh
exports/
  agent-config/
    agent-fleet.yaml
    orchestrator/
      policy.md
    specialists/
      stacks.md
      jennifer.md
      steve.md
      business.md
      podcast_media.md
      research.md
      engineering.md
```

## Source vs export

The private repo may keep standards-based source files:

- `SOUL.md`
- `AGENT.md`
- `MEMORY.md`

But the current public bootstrap path still consumes an exported `agent-config`
tree.

So the current contract is:

- private repo source of truth = standards-based files
- private repo export artifact = `exports/agent-config/`
- public bootstrap copies `exports/agent-config/` into
  `/opt/clawbot/config/agent-config/`

This keeps the public repo free of the private identity content while avoiding a
full prompt compiler in bootstrap.

## Bootstrap integration

The public bootstrap runner now supports:

- `OPENCLAW_AGENT_PACK_REPO_URL`
- `OPENCLAW_AGENT_PACK_REF`

If configured, bootstrap will:

1. clone the private repo at the pinned ref
2. read `exports/agent-config/`
3. overlay that tree into `/opt/clawbot/config/agent-config/`
4. only fall back to the public embedded templates when the private export is
   absent

## Private repo auth

Recommended production path:

- use an SSH deploy key
- keep it on the persisted `/opt` volume
- path:
  - `/opt/clawbot-root/bootstrap/agent-pack-deploy-key`
- owner:
  - `root:root`
- mode:
  - `600`

This avoids putting the private repo key into cloud-init or Terraform state.

## Pinning

Do not fetch `main` blindly in production.

Use a pinned ref:

- tag
- release branch
- or exact commit SHA

That keeps agent identity changes deliberate and reviewable.

## Milestones

### M-private-1

Create the private repo and commit the standards-based source structure.

### M-private-2

Add the private repo export step so it produces `exports/agent-config/`.

### M-private-3

Wire the production stack to:

- set the private repo URL
- set the pinned ref
- place the deploy key at `/opt/clawbot-root/bootstrap/agent-pack-deploy-key`

### M-private-4

Rebuild and verify that production uses the private export instead of the public
fallback templates.

### M-private-5

Delete or sharply reduce the embedded fallback persona content from the public
bootstrap runner, keeping only minimal emergency stubs.
