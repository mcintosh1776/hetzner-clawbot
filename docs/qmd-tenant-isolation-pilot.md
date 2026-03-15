# QMD Tenant-Isolation Pilot

## Purpose

Define a safe pilot plan for evaluating `QMD` as the retrieval/indexing layer for the future multi-tenant memory system.

This pilot is specifically for:

- `tenant_0`
- named specialist bots
- strict tenant isolation
- bot-scoped memory boundaries inside the tenant

This is not a generic memory trial.
It is a controlled evaluation of `QMD` as one layer in the larger memory architecture.

## Pilot scope

This pilot evaluates `QMD` only as:

- retrieval/indexing

This pilot does not treat `QMD` as:

- canonical truth
- session-state storage
- the full memory system

## Layer model for the pilot

### Canonical truth

Remains:

- text-first memory files
- tenant- and bot-scoped

### Retrieval/indexing

Pilot:

- `QMD`

### Session continuity

Not included in this pilot.
That remains a separate future evaluation, likely including `lossless-claw` or similar.

## Security requirement

The pilot must prove that:

1. one tenant cannot access another tenant's memory
2. one bot cannot automatically read another bot's private memory within the same tenant
3. the retrieval layer cannot become a hidden cross-tenant or cross-bot leakage surface

## Core security rule

`QMD` is not the security boundary.

The platform is the security boundary.

That means:

- storage layout
- namespace design
- query authorization
- service routing

must all enforce separation explicitly.

## Recommended pilot design

## 1. Storage model

Use one `QMD` index per tenant for the first pilot.

For `tenant_0`:

- canonical source files live under:
  - `/opt/clawbot/tenants/tenant_0/memory/canonical/...`
- `QMD` retrieval data lives under:
  - `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`

### Why one index per tenant

Pros:

- real cross-tenant separation
- easier operational reasoning
- lower chance of accidental cross-tenant query leakage
- simpler first pilot than per-bot index sprawl

Limitation:

- bot-vs-bot separation still requires scope filtering above the index

## 2. Scope model inside the tenant

Documents in the tenant index must still carry scope labels.

Minimum scopes:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/stacks`
- `tenant/tenant_0/bot/jennifer`
- `tenant/tenant_0/bot/steve`
- `tenant/tenant_0/bot/number5`
- `tenant/tenant_0/bot/bob`
- `tenant/tenant_0/operator`

## 3. Query model

Bots must not query `QMD` directly.

Instead:

- bot asks memory service
- memory service receives:
  - `tenant_id`
  - `bot_id`
  - requested purpose
- memory service decides which scopes are readable
- memory service queries `QMD`
- memory service returns only allowed results

This is the safe pattern.

## 4. Allowed scope reads for pilot

### Stacks

Allowed:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/stacks`

### Jennifer

Allowed:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/jennifer`

### Steve

Allowed:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/steve`

### Number5

Allowed:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/number5`

### Bob

Allowed for first pilot:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/bob`

Do not give Bob raw cross-bot private retrieval in the first pilot.

### Operator scope

No bot reads:

- `tenant/tenant_0/operator`

by default

## 5. Canonical file set for pilot

Keep the first pilot intentionally small.

Recommended source set:

### Tenant shared

- brand/voice rules
- approval conventions
- shared naming/style patterns

### Bot private

- Stacks durable tone preferences
- Jennifer editorial caution preferences
- maybe one Bob coordination preference

Do not start by indexing everything.

## 6. Daily memory consolidation

The pilot should include the design for a daily reflection job, but not auto-promotion to canonical truth.

Recommended daily job behavior:

1. review selected recent conversations and workflow outcomes
2. identify candidate durable memories
3. write them to:
   - observation/staging memory
4. do not auto-write permanent canonical memory by default

This keeps the memory pipeline disciplined.

## What the pilot should test

## Functional tests

1. shared memory retrieval works
2. bot-private retrieval works
3. irrelevant docs are not returned

## Security tests

1. `Stacks` cannot retrieve `Jennifer` bot-private memory
2. `Jennifer` cannot retrieve `Stacks` bot-private memory
3. no path allows cross-tenant retrieval
4. operator-private memory is not returned to bots

## Operational tests

1. index rebuild works from canonical files
2. deleting/rebuilding the retrieval index does not lose truth
3. query latency is acceptable for tenant_0 size

## What success looks like

The pilot is successful if:

1. canonical memory remains text-first
2. `QMD` improves retrieval quality meaningfully
3. tenant and bot separation remain intact
4. the retrieval layer can be rebuilt without losing truth
5. the design still scales conceptually to many tenants

## What failure looks like

The pilot fails if:

1. it encourages treating the index as truth
2. bot-private memory leaks between bots
3. cross-tenant separation is difficult to enforce
4. operational complexity is too high for the benefit
5. debugging becomes opaque

## Implementation stages

## Stage 1: canonical memory only

Before touching `QMD`:

- create first real canonical memory files for `tenant_0`
- define scopes cleanly

## Stage 2: build tenant_0 retrieval root

Create:

- `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`

## Stage 3: index small controlled corpus

Index only:

- tenant shared files
- Stacks files
- Jennifer files
- maybe Bob files

## Stage 4: add policy-enforcing query service

Do not let bots query raw `QMD`.

Add a thin service layer that:

- accepts tenant/bot context
- enforces allowed scopes
- returns filtered retrieval results

## Stage 5: run bot-scoped retrieval tests

Use controlled prompts and verify scope isolation.

## Stage 6: evaluate whether to expand

Only after proving:

- retrieval quality
- bot isolation
- operational clarity

## Recommendation

Proceed with `QMD` only if the pilot is implemented as:

- text-first canonical memory
- tenant-scoped index
- bot-scoped query filtering
- no direct bot access to raw shared retrieval storage

That is the safe version worth testing.

## Immediate next actions

1. create first canonical memory entries for `tenant_0`
2. define the observation memory staging flow
3. then prepare the smallest possible `QMD` pilot corpus
