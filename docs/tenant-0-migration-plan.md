# Tenant 0 Migration Plan

## Purpose

Define a safe migration path from the current single-tenant-ish production layout to the hardened `tenant_0` architecture without losing:

- current bot behavior
- current channel wiring
- current proposal/publish workflows
- current useful learned guidance and operator preferences

This plan is explicitly continuity-first.
It is not a rewrite plan.

## Core migration rule

Keep current bots useful while hardening the platform underneath them.

That means:

- do not stop productive work to chase architecture purity
- do not do destructive state moves early
- do not break working channels casually
- migrate one state family at a time
- cut over only after the replacement path is real

## What must be preserved

## 1. Bot identity and personality

Preserve:

- names
- roles
- private agent-pack guidance
- merged proposal-based behavior improvements

Primary source:

- `clawbot-agents`

## 2. Working external integrations

Preserve:

- Telegram behavior
- Nostr publish/sign flows
- proposal PR workflows
- current repo bindings

## 3. Durable runtime/service state

Preserve where useful:

- runtime state
- proposal service state
- channel dedupe state
- repo clone state
- service-specific working files

## 4. Operator trust and continuity

Preserve:

- the feeling that `Bob`, `Stacks`, `Jennifer`, `Steve`, and `Number5` remain the same working agents

## Migration strategy

## Strategy summary

Use a dual-structure migration:

1. keep current paths working
2. introduce tenant-aware target paths in parallel
3. migrate one domain at a time
4. use compatibility fallback during transition
5. only remove legacy assumptions after the new path is proven

## Migration phases

## Phase 0: freeze the architecture target

Inputs:

- [tenant-fleet-architecture.md](/home/mcintosh/repos/hetzner-clawbot/docs/tenant-fleet-architecture.md)
- [tenant-0-naming-and-paths.md](/home/mcintosh/repos/hetzner-clawbot/docs/tenant-0-naming-and-paths.md)
- [memory-schema.md](/home/mcintosh/repos/hetzner-clawbot/docs/memory-schema.md)
- [tenant-0-implementation-checklist.md](/home/mcintosh/repos/hetzner-clawbot/docs/tenant-0-implementation-checklist.md)

Completion criteria:

- `tenant_0` model accepted
- path model accepted
- memory model accepted

## Phase 1: inventory current state families

Goal:

Identify what exists today and map it to the future structure.

Current path families to inventory:

- `/opt/clawbot/state/private-runtimes/`
- `/opt/clawbot/state/proposal-services/`
- `/opt/clawbot/state/telegram-webhook/`
- `/opt/clawbot/repos/`
- `/opt/clawbot/config/`
- `/opt/clawbot-root/bootstrap/`

For each family record:

- current path
- current owner
- current purpose
- secret or non-secret
- canonical / session / service / config / repo classification
- target tenant-aware path

Completion criteria:

- every important current path family has a target mapping

## Phase 2: preserve durable bot behavior first

Goal:

Make sure behavior/personality work is not trapped in runtime state.

Actions:

- continue using `clawbot-agents` as source of truth for personality/policy
- merge the high-value behavior changes already proven useful
- capture important learned operator preferences as canonical memory entries or repo guidance

Completion criteria:

- important current bot behavior is preserved in durable reviewable sources

## Phase 3: introduce tenant-aware target roots

Goal:

Create the new target structure without cutting over current services immediately.

Target roots:

- `/opt/clawbot/tenants/tenant_0/`
- `/opt/clawbot-root/tenants/tenant_0/`

Target subtrees:

- `state/`
- `config/`
- `repos/`
- `memory/`
- `secrets/`
- `bootstrap/`
- `services/`

Important rule:

- creating the target roots does not imply moving everything immediately

Completion criteria:

- target root layout exists conceptually and, where useful, physically

## Phase 4: migrate low-risk state first

Goal:

Move the easiest, least dangerous path families before touching secrets or critical live workflows.

Recommended first migrations:

### 4.1 Telegram dedupe state

Current:

- `/opt/clawbot/state/telegram-webhook/`

Target:

- `/opt/clawbot/tenants/tenant_0/state/channels/telegram/`

Reason:

- low-risk
- operationally important
- good first proof of tenant-aware state paths

### 4.2 Proposal service state

Current:

- `/opt/clawbot/state/proposal-services/<bot_id>/`

Target:

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/proposal-service/`

Reason:

- clearly bot-scoped
- not secret-heavy

### 4.3 Runtime state

Current:

- `/opt/clawbot/state/private-runtimes/<bot_id>/`

Target:

- `/opt/clawbot/tenants/tenant_0/state/bots/<bot_id>/runtime/`

Reason:

- bot-scoped
- aligns directly with the tenant model

Migration rule for these:

- prefer "new-path first, old-path fallback" reads during transition
- do not remove legacy path writes until the new path is proven

## Phase 5: establish tenant_0 memory in parallel

Goal:

Start the memory system without waiting for every other migration step.

Actions:

- create canonical memory roots
- create observation roots
- create retrieval root
- create initial canonical entries

Important rule:

- new memory system starts alongside current runtime state
- do not confuse session state migration with canonical memory creation

Completion criteria:

- `tenant_0` has real canonical memory files in the defined schema

## Phase 6: migrate repo and proposal routing assumptions

Goal:

Make proposal/Git behavior tenant-aware in structure even if only `tenant_0` exists.

Current repo path:

- `/opt/clawbot/repos/clawbot-agents`

Target repo path:

- `/opt/clawbot/tenants/tenant_0/repos/clawbot-agents`

Recommended approach:

- do not rush this move if the current path is stable
- first make code and docs understand that the repo is tenant-owned
- then migrate the path with compatibility if needed

Completion criteria:

- proposal services conceptually and operationally target tenant-owned repos

## Phase 7: migrate secrets and privileged material carefully

Goal:

Move root-owned secrets into tenant-aware layout without breaking live services.

Current root secret area:

- `/opt/clawbot-root/bootstrap/`

Target:

- `/opt/clawbot-root/tenants/tenant_0/bootstrap/`
- `/opt/clawbot-root/tenants/tenant_0/secrets/`

Important:

- this is not the first migration
- do this only after the lower-risk path families and compatibility rules are proven

Migration rule:

- use copy + path-switch + validation
- not move-and-pray

## Phase 8: remove legacy assumptions

Goal:

Remove "one global tenant" assumptions only after tenant-aware replacements are in place.

Examples:

- hardcoded global state roots
- global webhook dedupe assumptions
- global proposal repo assumptions
- global secret path assumptions

Completion criteria:

- new code defaults to tenant-aware layout
- old assumptions only remain where explicitly grandfathered

## Compatibility strategy

This is the most important implementation discipline.

## Read strategy

Prefer:

1. read from new tenant-aware path first
2. fall back to legacy path if missing

This allows gradual migration without immediate breakage.

## Write strategy

Preferred rollout:

1. write to legacy path while new reader compatibility is added
2. then switch writes to new path once reads are proven
3. then retire legacy path use later

For some path families dual-write may be useful, but it should be used sparingly.

## Secret strategy

For secrets:

- never dual-write casually without intent
- prefer explicit copy and path cutover
- keep ownership/mode strict at every step

## Migration order recommendation

Use this order:

1. documents and ids
2. capability tiers
3. Telegram dedupe path
4. proposal-service state path
5. runtime state path
6. canonical memory roots and first entries
7. repo path assumptions
8. root secret/bootstrap paths

This order minimizes risk.

## What should not be migrated early

Avoid moving these too soon:

- live secrets
- signer key material
- Telegram tokens
- critical publish/sign wiring
- anything that would break current productive use

## Productivity rule

Current bots should continue doing useful work during migration.

Examples:

- `Steve` building websites
- `Stacks` handling media/promo
- `Jennifer` handling research/editorial

Architecture work must not become a freeze on productive use.

## Concrete preservation actions

## 1. Preserve bot behavior in durable sources

Checklist:

- [ ] merge valuable proposal PRs in `clawbot-agents`
- [ ] convert important repeated operator preferences into canonical memory or reviewed guidance

## 2. Preserve runtime state safely

Checklist:

- [ ] inventory current state paths before path migration
- [ ] identify which state is discardable, migratable, or should be reset

## 3. Preserve continuity for users

Checklist:

- [ ] keep bot names stable
- [ ] keep channel identities stable during migration
- [ ] avoid unnecessary behavior resets

## Rollback rules

Each migration step should have a rollback story.

### For low-risk path migrations

Rollback:

- point readers/writers back to legacy paths

### For secret path migrations

Rollback:

- restore previous known-good secret path references
- do not delete old secret location until cutover is proven

### For memory system rollout

Rollback:

- session/state continues working even if canonical memory adoption pauses

## Milestone plan

## Milestone 1

Documents accepted:

- architecture
- tenant naming/paths
- memory schema
- migration plan

## Milestone 2

Current state inventory completed and mapped to target paths.

## Milestone 3

Capability tiers written for current fleet.

## Milestone 4

First tenant-aware low-risk path family migrated successfully.

## Milestone 5

First canonical `tenant_0` memory entries created.

## Milestone 6

At least one current working feature is running on tenant-aware conventions without losing continuity.

## Recommended next actions

1. accept this migration plan
2. create the current-state inventory
3. write the capability-tier matrix
4. create the first canonical memory entries
5. choose the first low-risk path family to migrate
