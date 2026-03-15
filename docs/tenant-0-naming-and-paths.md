# Tenant 0 Naming and Paths

## Purpose

Define the concrete naming, path, and ownership conventions for the current Satoshi's Plebs deployment as `tenant_0`.

This is the implementation-facing companion to [tenant-fleet-architecture.md](/home/mcintosh/repos/hetzner-clawbot/docs/tenant-fleet-architecture.md).

## Tenant identity

Current production reference tenant:

- `tenant_id = tenant_0`
- display label: `Satoshi's Plebs`

This is the first tenant fleet and the reference for future tenant-aware design.

## Bot identities

Current `tenant_0` fleet:

- `bob`
  - display name: `Bob`
  - internal agent id: `orchestrator`
- `stacks`
  - display name: `Stacks`
  - internal agent id: `podcast_media`
- `jennifer`
  - display name: `Jennifer`
  - internal agent id: `research`
- `steve`
  - display name: `Steve`
  - internal agent id: `engineering`
- `number5`
  - display name: `Number5`
  - internal agent id: `business`

## Naming rules

### Tenant ids

Format:

- lowercase
- ASCII
- stable
- no spaces
- preferred pattern:
  - `tenant_<n>` for early internal tenants
  - later, a durable slug model may replace this

For now:

- `tenant_0`

### Public bot ids

Format:

- lowercase
- kebab or flat lowercase if already established
- stable public routing key

Current values:

- `bob`
- `stacks`
- `jennifer`
- `steve`
- `number5`

### Internal agent ids

These remain the private agent-pack identifiers:

- `orchestrator`
- `podcast_media`
- `research`
- `engineering`
- `business`

Rule:

- public bot id is the channel/runtime identity
- internal agent id is the agent-pack/config identity

Do not collapse those two concepts.

## Path model

## Root directories

Current durable root:

- `/opt/clawbot`

Current root-owned durable root:

- `/opt/clawbot-root`

## Tenant-scoped path target

Future tenant-aware paths should nest under:

- `/opt/clawbot/tenants/<tenant_id>/...`
- `/opt/clawbot-root/tenants/<tenant_id>/...`

For `tenant_0`, the target shape is:

- `/opt/clawbot/tenants/tenant_0/...`
- `/opt/clawbot-root/tenants/tenant_0/...`

## Recommended path layout

### Tenant public/durable state

- `/opt/clawbot/tenants/tenant_0/state/`

Subpaths:

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/`
- `/opt/clawbot/tenants/tenant_0/state/shared/`
- `/opt/clawbot/tenants/tenant_0/state/operator/`

### Tenant config

- `/opt/clawbot/tenants/tenant_0/config/`

Subpaths:

- `/opt/clawbot/tenants/tenant_0/config/agent-config/`
- `/opt/clawbot/tenants/tenant_0/config/channels/`
- `/opt/clawbot/tenants/tenant_0/config/policy/`

### Tenant repos

- `/opt/clawbot/tenants/tenant_0/repos/`

Example:

- `/opt/clawbot/tenants/tenant_0/repos/clawbot-agents`

### Tenant memory

- `/opt/clawbot/tenants/tenant_0/memory/`

Subpaths:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/`
- `/opt/clawbot/tenants/tenant_0/memory/retrieval/`
- `/opt/clawbot/tenants/tenant_0/memory/session/`

### Root-owned tenant secrets and privileged material

- `/opt/clawbot-root/tenants/tenant_0/secrets/`
- `/opt/clawbot-root/tenants/tenant_0/bootstrap/`
- `/opt/clawbot-root/tenants/tenant_0/services/`

Examples:

- Telegram bot tokens
- signing keys
- GitHub App credentials
- privileged helper configs

## Current-to-target mapping

Current paths should eventually migrate like this.

### Runtime state

Current:

- `/opt/clawbot/state/private-runtimes/<bot_id>/`

Target:

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/runtime/`

Examples:

- `/opt/clawbot/tenants/tenant_0/state/bots/stacks/runtime/`
- `/opt/clawbot/tenants/tenant_0/state/bots/jennifer/runtime/`

### Proposal services

Current:

- `/opt/clawbot/state/proposal-services/<bot_id>/`

Target:

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/proposal-service/`

### Telegram webhook dedupe state

Current:

- `/opt/clawbot/state/telegram-webhook/`

Target:

- `/opt/clawbot/tenants/tenant_0/state/channels/telegram/`

### Private repo clone

Current:

- `/opt/clawbot/repos/clawbot-agents`

Target:

- `/opt/clawbot/tenants/tenant_0/repos/clawbot-agents`

### Root bootstrap materials

Current:

- `/opt/clawbot-root/bootstrap/...`

Target:

- `/opt/clawbot-root/tenants/tenant_0/bootstrap/...`

## Ownership rules

### Root-owned

Use `root:root` and strict modes for:

- secrets
- signing material
- GitHub App credentials
- root-run service configs
- privileged helper binaries and service state

### Tenant service-owned

Use service user ownership where appropriate for:

- runtime state
- proposal state
- channel dedupe state
- non-secret working files

### Human operator clones

For tenant repo working trees that may be inspected by operators:

- prefer a stable path under tenant repos
- ownership depends on usage model
- if root-run services need access, design that access explicitly instead of loosening secret ownership broadly

## Naming conventions for config keys

Future tenant-aware configuration should carry both:

- `tenant_id`
- `bot_id`

Recommended examples:

- `OPENCLAW_TENANT_ID=tenant_0`
- `OPENCLAW_BOT_ID=stacks`
- `OPENCLAW_AGENT_ID=podcast_media`

These should be explicit, not inferred from path names when avoidable.

## Channel ownership

External channels should become tenant-scoped first, bot-scoped second.

Example model:

- tenant owns Telegram integration surface
- bot owns specific Telegram bot identity/token within tenant

The same pattern should apply later to:

- Nostr
- email
- YouTube

## Repo ownership rules

Tenant bots may only target tenant-owned repos or tenant-owned paths within a repo.

For `tenant_0`:

- primary private behavior repo:
  - `clawbot-agents`

Future rule:

- tenant-specific proposal services must know `tenant_id`
- repo routing must validate tenant ownership before opening PRs

## Immediate implementation guidance

Until full tenantization is implemented in code:

1. treat current deployment as `tenant_0`
2. avoid adding any new path/state conventions that assume a single global tenant forever
3. prefer new code that can be migrated to:
   - `/opt/clawbot/tenants/<tenant_id>/...`
4. preserve distinction between:
   - public bot id
   - internal agent id
   - tenant id

## First migration candidates

These are the first path families that should become tenant-aware:

1. runtime state paths
2. proposal-service state paths
3. Telegram dedupe paths
4. repo clone path
5. root bootstrap secret paths

## Success criteria

This document is successful if future code changes can answer:

1. which tenant owns this state
2. which bot owns this state
3. whether this path is secret, runtime, memory, repo, or channel state
4. how this path would coexist with 49 other tenants without collision
