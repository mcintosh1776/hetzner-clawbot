# Current State Inventory

## Purpose

Capture the current live system structure in a way that supports migration to the `tenant_0` architecture without losing useful state or making unsafe assumptions.

This document is a mapping tool.
It is not the final architecture.

## Scope

This inventory covers the known important path families and runtime domains for the current deployment.

Reference tenant:

- `tenant_id = tenant_0`

Reference fleet:

- `Bob`
- `Stacks`
- `Jennifer`
- `Steve`
- `Number5`

## Inventory format

For each path family or subsystem, record:

- current location
- current purpose
- ownership
- classification
- target tenant-aware location
- migration notes

## Classifications

Use one of:

- `canonical`
- `session`
- `service_state`
- `config`
- `repo`
- `secret`
- `integration`

## Inventory

## 1. Private runtime state

### Current location

- `/opt/clawbot/state/private-runtimes/<bot_id>/`

### Purpose

- per-bot runtime operational state
- pending drafts
- pending proposals
- last-opened proposal tracking
- transient workflow state

### Ownership

- bot-owned within current single-tenant deployment

### Classification

- `session`

### Target location

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/runtime/`

### Migration notes

- high-value for bot continuity
- should be migrated carefully
- should not be confused with canonical memory
- readers should eventually prefer new path and fall back to old path during migration

## 2. Proposal service state

### Current location

- `/opt/clawbot/state/proposal-services/<bot_id>/`

### Purpose

- per-bot proposal service operational state
- sockets and service-specific working state

### Ownership

- bot-owned service state

### Classification

- `service_state`

### Target location

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/proposal-service/`

### Migration notes

- good early migration candidate
- clearly bot-scoped
- not canonical and not tenant-global

## 3. Telegram webhook dedupe state

### Current location

- `/opt/clawbot/state/telegram-webhook/`

### Purpose

- dedupe and stale-event handling for Telegram updates

### Ownership

- tenant channel state

### Classification

- `service_state`

### Target location

- `/opt/clawbot/tenants/tenant_0/state/channels/telegram/`

### Migration notes

- strong candidate for first low-risk migration
- easy win for tenant-aware pathing

## 4. Durable repo clone

### Current location

- `/opt/clawbot/repos/clawbot-agents`

### Purpose

- local durable clone of private agent-pack repo
- used by proposal workflow

### Ownership

- tenant-owned repo binding

### Classification

- `repo`

### Target location

- `/opt/clawbot/tenants/tenant_0/repos/clawbot-agents`

### Migration notes

- important for proposal continuity
- do not move casually while proposal flow is live
- tenant ownership should be recognized in code/docs before path cutover

## 5. Generated agent config

### Current location

- `/opt/clawbot/config/agent-config/`

### Purpose

- rendered agent prompts/config for runtimes

### Ownership

- tenant config with bot-specific outputs

### Classification

- `config`

### Target location

- `/opt/clawbot/tenants/tenant_0/config/agent-config/`

### Migration notes

- generated from tenant-owned source material
- should eventually be tenant-scoped even if still rendered centrally at first

## 6. Telegram webhook app/config

### Current location

- `/opt/clawbot/config/telegram-webhook/`

### Purpose

- webhook relay code and local runtime-facing integration

### Ownership

- tenant integration config

### Classification

- `integration`

### Target location

- `/opt/clawbot/tenants/tenant_0/config/channels/telegram/`

### Migration notes

- migration should be separate from webhook token secret migration

## 7. Root bootstrap materials

### Current location

- `/opt/clawbot-root/bootstrap/`

### Purpose

- deploy keys
- GitHub App credentials
- bootstrap runner and root-only helper materials

### Ownership

- tenant-owned privileged material in current single-tenant layout

### Classification

- `secret`

### Target location

- `/opt/clawbot-root/tenants/tenant_0/bootstrap/`
- `/opt/clawbot-root/tenants/tenant_0/secrets/`

### Migration notes

- high-risk migration
- do late
- use copy and explicit cutover, not move-first

## 8. Signer service state and config

### Current location

- distributed across current runtime/service setup under `/opt/clawbot/...` and root-owned setup

### Purpose

- Nostr signing/publish flows
- signer sockets/config

### Ownership

- bot-specific privileged integration within a tenant

### Classification

- `integration`
- `secret` for underlying key material paths

### Target location

- tenant-scoped privileged service paths under `/opt/clawbot-root/tenants/tenant_0/services/`
- related runtime-visible non-secret state under `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/`

### Migration notes

- do not move early
- maintain working publish/sign flows until new layout is fully proven

## 9. Current private agent-pack repo

### Current external location

- GitHub private repo `clawbot-agents`

### Purpose

- source of truth for personality, guidance, exported config inputs, and proposal target

### Ownership

- tenant-owned behavior repo for current deployment

### Classification

- `repo`
- behavior source of truth

### Target role in architecture

- remain tenant-owned source of truth for identity/policy/guidance

### Migration notes

- preserve as-is
- do not replace with runtime-state memory
- future tenants likely need their own equivalent repos or tenant-scoped sections

## 10. Emerging memory and preferences

### Current location

- partially in `clawbot-agents`
- partially in runtime/session state
- partially in operator knowledge only

### Purpose

- learned preferences
- behavior refinements
- operator corrections

### Ownership

- mixed; currently under-specified

### Classification

- partly `canonical`
- partly `session`
- partly not yet captured

### Target location

- canonical memory under:
  - `/opt/clawbot/tenants/tenant_0/memory/canonical/`
- observational memory under:
  - `/opt/clawbot/tenants/tenant_0/memory/observations/`

### Migration notes

- highest conceptual importance
- do not assume current runtime state is a reliable long-term store
- start capturing important durable preferences deliberately

## 11. Current channels

### Current examples

- Telegram bot identities per current bot
- Nostr identities for publishing-capable bots

### Purpose

- external tenant-facing interaction surfaces

### Ownership

- tenant-owned channels with bot-specific identities

### Classification

- `integration`

### Target location

- config and state under tenant-scoped channel paths
- secrets under tenant-scoped root secret paths

### Migration notes

- channel identity continuity is critical
- do not break this during path cleanup

## 12. Current bot fleet model

### Current state

- effectively a single-tenant named bot fleet

### Ownership

- `tenant_0`

### Classification

- architecture baseline

### Target role

- proving ground for the multi-tenant fleet model

## Current-to-target summary

| Current | Target | Type | Migration priority |
| --- | --- | --- | --- |
| `/opt/clawbot/state/private-runtimes/...` | `/opt/clawbot/tenants/tenant_0/state/bots/.../runtime/` | session | medium |
| `/opt/clawbot/state/proposal-services/...` | `/opt/clawbot/tenants/tenant_0/state/bots/.../proposal-service/` | service_state | medium |
| `/opt/clawbot/state/telegram-webhook/` | `/opt/clawbot/tenants/tenant_0/state/channels/telegram/` | service_state | high |
| `/opt/clawbot/repos/clawbot-agents` | `/opt/clawbot/tenants/tenant_0/repos/clawbot-agents` | repo | medium |
| `/opt/clawbot/config/agent-config/` | `/opt/clawbot/tenants/tenant_0/config/agent-config/` | config | low-medium |
| `/opt/clawbot/config/telegram-webhook/` | `/opt/clawbot/tenants/tenant_0/config/channels/telegram/` | integration | low-medium |
| `/opt/clawbot-root/bootstrap/` | `/opt/clawbot-root/tenants/tenant_0/bootstrap/` | secret | low, later |

## Recommended first migration candidate

Best first candidate:

- Telegram webhook dedupe state

Why:

- low risk
- easy to reason about
- clearly tenant channel state
- immediately useful proof of tenant-aware layout

## Recommended immediate preservation actions

1. keep current bot behavior source-of-truth in `clawbot-agents`
2. start writing canonical memory entries for the most important learned preferences
3. do not treat runtime pending-state files as durable truth
4. move low-risk state first, not secrets first

## Open inventory items

These need deeper mapping later:

- exact signer state and secret path mapping
- exact channel token secret layout by bot
- exact generated config ownership and rendering path strategy
- any future mail or YouTube integration paths

## Recommended next actions

1. accept this inventory as the current baseline
2. choose the first low-risk path family to migrate
3. create the first canonical memory entries for `tenant_0`
4. begin implementing tenant-aware path conventions in new code
