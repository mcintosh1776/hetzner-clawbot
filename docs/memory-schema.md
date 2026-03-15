# Memory Schema

## Purpose

Define the first concrete memory model for the tenant-fleet architecture.

This document specifies:

- memory layers
- memory scopes
- canonical entry schema
- retrieval/indexing rules
- promotion rules
- storage placement

This is the working schema for `tenant_0` and the template for future tenants.

## Design goals

The memory system must satisfy all of these constraints:

- hard tenant isolation
- narrow bot-specific memory where appropriate
- human-readable canonical truth
- rebuildable retrieval layer
- separation between durable truth and temporary runtime state
- safe scaling to many tenants and many bots

## Memory layers

The platform should treat memory as three distinct layers.

## 1. Canonical memory

Purpose:

- durable truth
- curated preferences
- approved facts
- long-term behavioral knowledge

Properties:

- text-first
- human-readable
- reviewable
- portable
- not dependent on any one embedding/index engine

Canonical memory is the source of truth.

## 2. Retrieval memory

Purpose:

- semantic search
- long-horizon recall
- efficient retrieval for runtime context assembly

Properties:

- derived from canonical memory and selected observational/session sources
- rebuildable
- disposable
- never the only durable copy

Retrieval memory is an index, not truth.

## 3. Session memory

Purpose:

- short-term working context
- in-flight tasks
- pending approvals
- temporary summaries
- transient conversation state

Properties:

- may persist on disk
- replaceable
- not canonical by default

Session memory is operational state, not durable truth.

## Memory scopes

Every memory item must exist in a scope.

## Scope types

### Tenant shared

Format:

- `tenant/<tenant_id>/shared`

Purpose:

- facts or preferences shared across a tenant fleet
- tenant-wide writing norms
- organization-specific conventions

Examples:

- brand voice
- audience profile
- approval policy
- common formatting conventions

### Bot private

Format:

- `tenant/<tenant_id>/bot/<bot_id>`

Purpose:

- memories specific to one named specialist

Examples:

- Stacks social tone preferences
- Jennifer editorial caution rules
- a YouTube bot's script pacing rules

### Operator private

Format:

- `tenant/<tenant_id>/operator`

Purpose:

- information that should not be automatically available to tenant bots

Examples:

- internal operator notes
- sensitive preferences
- candid reviews not yet promoted to bot-visible memory

### Platform public

Format:

- `platform/public`

Purpose:

- generic non-sensitive shared defaults
- public templates and common knowledge safe for broad reuse

This should stay small.

## Access rules

Default read rules:

- bot may read:
  - its own bot scope
  - allowed tenant shared scope
  - allowed platform public scope
- bot may not read:
  - other bot scopes by default
  - operator scope by default
  - any other tenant scope ever

Default write rules:

- bots may create observational/session memory in their own scope if allowed
- bots may not directly write canonical memory without review
- promotion into canonical memory requires an explicit controlled workflow

## Canonical memory entry schema

Canonical memory entries should be stored as text files with structured metadata and a body.

Recommended format:

- frontmatter plus markdown body

Example:

```md
---
id: stacks-tone-warmth-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/stacks
bot_id: stacks
type: preference
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - tone
  - social
  - warmth
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Stacks should sound warm and approachable in audience-facing writing without becoming chatty,
hype-driven, or fluffy. Warmth means sounding like a real person who cares about the work and
the audience.
```

## Required metadata fields

- `id`
- `tenant_id`
- `scope`
- `type`
- `status`
- `visibility`
- `source`
- `confidence`
- `created_at`
- `updated_at`

## Optional metadata fields

- `bot_id`
- `tags`
- `reviewed_by`
- `expires_at`
- `supersedes`
- `related_ids`
- `external_ref`

## Field definitions

### `id`

Stable unique identifier for the memory entry.

Recommended pattern:

- `<slug>-<nnn>`

Examples:

- `stacks-tone-warmth-001`
- `tenant-brand-voice-001`

### `tenant_id`

Hard ownership field.

Example:

- `tenant_0`

### `scope`

One of the allowed memory scopes.

Examples:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/stacks`
- `tenant/tenant_0/operator`

### `type`

Recommended enum set:

- `preference`
- `fact`
- `policy`
- `identity`
- `relationship`
- `task_pattern`
- `evaluation_note`
- `style_rule`

### `status`

Recommended values:

- `active`
- `superseded`
- `deprecated`
- `archived`

### `visibility`

Recommended values:

- `bot`
- `operator`
- `restricted`

### `source`

Recommended values:

- `operator_review`
- `merged_pr`
- `manual_import`
- `conversation_promotion`
- `external_system`

### `confidence`

Recommended values:

- `low`
- `medium`
- `high`

## Canonical directory layout

Recommended tenant path:

- `/opt/clawbot/tenants/<tenant_id>/memory/canonical/`

Suggested structure:

- `/opt/clawbot/tenants/<tenant_id>/memory/canonical/shared/`
- `/opt/clawbot/tenants/<tenant_id>/memory/canonical/bots/<bot_id>/`
- `/opt/clawbot/tenants/<tenant_id>/memory/canonical/operator/`

For `tenant_0`:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/shared/`
- `/opt/clawbot/tenants/tenant_0/memory/canonical/bots/stacks/`
- `/opt/clawbot/tenants/tenant_0/memory/canonical/bots/jennifer/`
- etc.

## What belongs in canonical memory

Examples:

- durable tenant writing preferences
- durable bot-specific tone rules
- approved style constraints
- stable audience descriptions
- approved platform/channel rules
- relationships that matter over time

## What does not belong in canonical memory

Examples:

- pending approvals
- last-opened proposal references
- one-off chat artifacts
- temporary reasoning traces
- noisy or unreviewed conversational scraps

## Retrieval memory model

Retrieval memory should be a derived index over selected memory sources.

## Indexable sources

Recommended index sources:

1. canonical memory entries
2. approved identity/policy docs from agent packs
3. selected conversation summaries
4. selected observational memory entries

Do not blindly index everything.

## Retrieval namespaces

At minimum, retrieval should support:

- tenant namespace
- bot namespace
- source type
- visibility filter

Recommended logical namespace pattern:

- `tenant:<tenant_id>:shared`
- `tenant:<tenant_id>:bot:<bot_id>`
- `tenant:<tenant_id>:operator`

## Retrieval storage location

Recommended durable location:

- `/opt/clawbot/tenants/<tenant_id>/memory/retrieval/`

This may contain:

- vector DB files
- full-text search indexes
- embedding metadata

The retrieval layer may be binary.
That is acceptable because it is derived.

## Session memory model

Session memory should hold short-horizon operational state.

Examples:

- pending post drafts
- pending proposal drafts
- last-opened proposal references
- recent conversation summaries
- current workflow state

Recommended location:

- `/opt/clawbot/tenants/<tenant_id>/memory/session/`

And/or:

- `/opt/clawbot/tenants/<tenant_id>/state/...`

depending on operational need

## Session memory rules

- session memory is not canonical
- session memory may expire
- session memory may be overwritten
- session memory should be easy to inspect and clear

## Observational memory

Observational memory is the staging area between session and canonical memory.

Purpose:

- capture candidate durable insights without immediately promoting them to truth

Examples:

- repeated operator preference noticed over time
- repeated editing pattern
- recurring audience preference

Recommended location:

- `/opt/clawbot/tenants/<tenant_id>/memory/observations/`

Recommended format:

- same frontmatter + markdown style as canonical memory
- but with:
  - `status: pending_review`
  - `source: conversation_promotion` or similar

## Promotion rules

This is the most important behavioral rule set.

### Session -> observation

Allowed when:

- an event seems likely to matter beyond the current session
- there is repeated evidence
- the bot or operator flags it as worth remembering

This should not require a full Git workflow in the first version.

### Observation -> canonical

Requires review.

Recommended allowed promotion paths:

- operator review
- Git-reviewed PR
- explicit admin promotion tool

Default rule:

- bots do not unilaterally promote canonical memory

## Git vs `/opt`

This is a design fork that needs a practical answer.

## Recommended split

### Git

Use Git for:

- identity and policy docs
- agent-pack guidance
- curated canonical memory that is important enough to review/version

Examples:

- bot personality rules
- tenant brand rules
- stable high-value preferences

### `/opt`

Use `/opt` for:

- retrieval indexes
- session memory
- observational memory inbox
- runtime state
- large or operationally noisy memory artifacts

This split keeps reviewable truth small and operational storage practical.

## Recommendation for first version

Start with:

- curated canonical memory in text files under `/opt/clawbot/tenants/<tenant_id>/memory/canonical/`
- later decide whether part or all of that becomes its own private Git repo

Reason:

- faster to implement
- less workflow overhead at the start
- still text-first and inspectable

Then move the high-value subset into Git if and when the review workflow demands it.

## Indexing rules

The retrieval layer should index:

- canonical memory
- selected observation entries
- selected approved agent identity docs

The retrieval layer should not index by default:

- raw secrets
- transient approval files
- low-value noisy session artifacts
- stale or closed workflow state

## Freshness and invalidation

Retrieval indexes must be invalidated or rebuilt when:

- canonical memory changes
- observation entries are promoted or removed
- relevant agent-pack identity files change

This can start simple:

- scheduled rebuild
- explicit rebuild command

No need for complex real-time sync in the first version.

## Memory write policy by capability tier

### `chat_only`

- may not write canonical memory
- may not write observation memory unless explicitly enabled

### `drafting`

- may write session memory
- may propose memory observations if enabled

### `proposal_capable`

- may create reviewed proposals for canonical memory or guidance updates

### `publishing_capable`

- same as above, plus approved publish flows

### `privileged`

- may access more sensitive workflows, but still should not bypass canonical review by default

## Tenant 0 first implementation recommendation

For `tenant_0`, I recommend:

1. create canonical text directories under `/opt/clawbot/tenants/tenant_0/memory/canonical/`
2. create observation inbox under `/opt/clawbot/tenants/tenant_0/memory/observations/`
3. continue using runtime state under tenant-scoped session/state directories
4. postpone final vector engine choice until scope model is locked
5. keep agent-pack repo as identity/policy source of truth
6. use memory files for durable tenant/bot knowledge that is not purely personality guidance

## Success criteria

This schema is successful if:

1. memory items can be clearly classified as canonical, retrieval, observation, or session
2. every memory item has a tenant scope
3. every bot's accessible memory can be explained precisely
4. retrieval storage can be deleted and rebuilt without losing truth
5. stale runtime state cannot be mistaken for durable memory

## Recommended next actions

1. review and tighten this schema
2. decide whether canonical memory starts in `/opt` or a private repo
3. define the first tenant_0 canonical memory entries
4. define the observation promotion workflow
5. choose the first retrieval engine after namespace rules are accepted
