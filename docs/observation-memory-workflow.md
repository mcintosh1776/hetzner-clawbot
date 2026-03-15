# Observation Memory Workflow

## Purpose

Define how candidate durable memories are captured without immediately becoming canonical truth.

This workflow exists to solve the tension between:

- fully manual long-term memory management
- unsafe fully automatic permanent memory writes

The answer is a middle layer:

- observation memory

## Layer position

Observation memory sits between:

- session/runtime memory
- canonical memory

It is:

- more durable than session state
- less authoritative than canonical memory

## Core rule

Bots may automatically produce observation memory.
Bots should not automatically promote canonical memory by default.

## What observation memory is for

Use it for:

- repeated operator preferences
- recurring edit patterns
- stable-seeming style corrections
- workflow lessons that might matter later
- candidate durable facts that need review

Do not use it for:

- raw noisy chat logs
- transient task state
- obvious one-off chatter
- secrets
- approvals/drafts that are only operational artifacts

## Observation entry format

Use the same general text-first shape as canonical memory, but with different status/source metadata.

Example:

```md
---
id: obs-stacks-warmth-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/stacks
bot_id: stacks
type: preference
status: pending_review
visibility: bot
source: conversation_promotion
confidence: medium
tags:
  - tone
  - warmth
  - social
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
---

Operator repeatedly preferred warmer, more human social writing for Stacks across multiple review cycles.
```

## Recommended storage location

Tenant-aware target:

- `/opt/clawbot/tenants/<tenant_id>/memory/observations/`

Suggested layout:

- `/opt/clawbot/tenants/<tenant_id>/memory/observations/shared/`
- `/opt/clawbot/tenants/<tenant_id>/memory/observations/bots/<bot_id>/`
- `/opt/clawbot/tenants/<tenant_id>/memory/observations/operator/`

## Creation paths

Observation memory can be created by:

### 1. Daily consolidation job

Recommended primary path.

The job reviews:

- recent conversations
- repeated revisions
- approval/rejection patterns
- recurring operator corrections

Then writes:

- candidate observations

not:

- canonical memory

### 2. Explicit operator request

Examples:

- `remember this`
- `this is a recurring rule`
- `keep this as a durable preference candidate`

This should create:

- observation memory immediately

### 3. Bot-detected repeated pattern

Allowed only if policy enables it.

The bot may note:

- “this has come up repeatedly”

and create an observation entry automatically or propose one.

## Confidence and review rules

Recommended defaults:

- low confidence:
  - weak signal, probably do not promote yet
- medium confidence:
  - repeated pattern, worth review
- high confidence:
  - strong repeated evidence or explicit operator confirmation

Important:

- even high-confidence observations should not automatically become canonical truth by default

## Promotion workflow

## Observation -> canonical

Recommended promotion paths:

1. operator review and explicit acceptance
2. Git-reviewed PR
3. explicit admin promotion tool

## Promotion criteria

Promote when the observation is:

- stable
- useful over time
- not obviously temporary
- clearly scoped
- worth retrieving in future work

## Do not promote when

- it is emotionally reactive noise
- it contradicts newer accepted guidance
- it is obviously session-specific
- it is not yet stable

## Expiry and cleanup

Observation memory should not grow forever without maintenance.

Recommended rules:

- stale unreviewed observations may expire
- observations promoted to canonical memory should be marked superseded or linked
- obviously bad observations should be discarded

Possible statuses:

- `pending_review`
- `accepted`
- `rejected`
- `expired`
- `superseded`

## Relationship to daily cron/summary jobs

The daily reflection job should:

1. summarize the day
2. identify candidate durable memories
3. create observation entries
4. optionally surface the best candidates for operator review

It should not:

- rewrite canonical truth automatically by default

## Recommended first-version behavior

For `tenant_0`:

1. keep session memory automatic
2. allow observation memory generation through:
   - explicit operator requests
   - later, daily consolidation
3. keep canonical promotion reviewed and deliberate

## Example flow

1. Operator repeatedly tells Stacks to be warmer but not hype-driven.
2. The system notices the recurring pattern.
3. An observation entry is created in Stacks' observation scope.
4. Later, the rule is accepted and promoted to canonical memory.
5. Retrieval layer indexes the canonical memory entry, not just the noisy original chat.

## Success criteria

The workflow is successful if:

1. bots do not silently write permanent truth too easily
2. important repeated patterns are still captured
3. operator review remains practical
4. memory quality improves over time instead of degrading into noise

## Recommended next actions

1. accept this workflow as the default observation model
2. decide whether first observation creation is manual, scheduled, or both
3. add the first real observation examples for `tenant_0`
