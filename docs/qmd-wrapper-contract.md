# QMD Wrapper Contract

## Purpose

Define the first concrete `QMD` integration contract for `tenant_0`.

This document answers:

- where `QMD` data should live
- what the memory service should accept
- what it should return
- how tenant and bot scope are enforced

This is the contract to implement before wiring `QMD` into bootstrap or runtime behavior.

## Scope

Reference tenant:

- `tenant_0`

Reference use:

- retrieval over canonical memory only

Out of scope for the first implementation:

- observation indexing
- cross-tenant operation
- direct bot access to raw `QMD`
- automatic canonical writes

## Core rule

Bots do not query `QMD` directly.

Bots query a memory wrapper service.
The wrapper service enforces:

- `tenant_id`
- `bot_id`
- allowed scopes

Then the wrapper talks to `QMD`.

## Storage layout

## Canonical source files

Current live root:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/`

## QMD home/index root

Recommended first location:

- `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`

This should be the tenant-scoped `QMD` home for the pilot.

## Temporary working area

If needed:

- `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/tmp/`

Keep this under the same tenant root.

## One index per tenant

For the first pilot:

- one `QMD` home/index per tenant

Not:

- one global index for all tenants
- one per-bot index by default

Reason:

- good tenant isolation
- simpler operational model
- avoids premature per-bot index sprawl

## Scope model inside the tenant

Documents must still carry scope metadata.

Minimum supported scopes for `tenant_0`:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/bob`
- `tenant/tenant_0/bot/stacks`
- `tenant/tenant_0/bot/jennifer`
- `tenant/tenant_0/bot/steve`
- `tenant/tenant_0/bot/number5`

Excluded from the first pilot:

- `tenant/tenant_0/operator`

## Wrapper responsibilities

The wrapper service must do all of the following:

1. accept tenant/bot-aware retrieval requests
2. resolve allowed scopes for that bot
3. map those scopes to the underlying corpus/index
4. issue the actual query to `QMD`
5. filter and normalize results
6. return only allowed items

## Request contract

## Request shape

Suggested JSON request:

```json
{
  "tenantId": "tenant_0",
  "botId": "stacks",
  "query": "warmer social tone for audience-facing posts",
  "purpose": "drafting",
  "maxResults": 5
}
```

## Required fields

- `tenantId`
- `botId`
- `query`

## Optional fields

- `purpose`
- `maxResults`
- `scopeHint`

## Request rules

### `tenantId`

Must match the tenant context of the calling runtime.

### `botId`

Must match the current bot identity.

### `query`

Plain-text retrieval query.

### `purpose`

Optional but useful for logging and later policy refinement.

Examples:

- `drafting`
- `style_recall`
- `planning`
- `memory_lookup`

### `scopeHint`

Optional.
Can be used to bias retrieval, but not to widen access.

Examples:

- `shared`
- `bot`

Important:

- bots may not use `scopeHint` to bypass scope rules

## Response contract

## Response shape

Suggested JSON response:

```json
{
  "ok": true,
  "tenantId": "tenant_0",
  "botId": "stacks",
  "results": [
    {
      "id": "stacks-social-warmth-001",
      "scope": "tenant/tenant_0/bot/stacks",
      "type": "preference",
      "path": "/opt/clawbot/tenants/tenant_0/memory/canonical/bots/stacks/stacks-social-warmth-001.md",
      "score": 0.92,
      "snippet": "Stacks should write with a warmer and friendlier tone..."
    }
  ]
}
```

## Result fields

- `id`
- `scope`
- `type`
- `path`
- `score`
- `snippet`

## Response rules

- only return scopes allowed for the bot
- do not expose operator-private content
- do not expose cross-bot private content
- keep snippets short and relevant

## Allowed scopes by bot for pilot

## Bob

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/bob`

## Stacks

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/stacks`

## Jennifer

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/jennifer`

## Steve

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/steve`

## Number5

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/number5`

## Indexing contract

## Initial corpus

Only index canonical memory files in the first pilot.

Current live files:

- shared brand voice
- Bob coordination boundaries
- Stacks social warmth
- Jennifer editorial discipline
- Steve engineering discipline
- Number5 business boundaries

## Index refresh model

First version should be simple:

- explicit rebuild command

Not:

- automatic real-time sync

## Rebuild rule

Deleting the `QMD` retrieval index must not lose truth.

The wrapper/indexer must be able to rebuild from:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/`

## Security model

## Hard boundaries

The wrapper must enforce:

- no cross-tenant retrieval
- no cross-bot private retrieval by default
- no operator-private retrieval in the first pilot

## Things the wrapper must not trust

Do not trust:

- caller-supplied path
- caller-supplied scope expansion
- caller-supplied tenant switching

The wrapper decides those from policy.

## Logging

Recommended logging per request:

- timestamp
- tenant id
- bot id
- purpose
- allowed scopes
- result count

Do not log:

- raw secrets
- large document bodies

## First implementation recommendation

Keep the first implementation very small.

## Phase 1

- build a local wrapper command or small service
- point it at the `tenant_0` canonical root
- support only one tenant

## Phase 2

- add bot-specific scope enforcement
- run retrieval tests

## Phase 3

- connect one bot, probably `Stacks`, for a constrained retrieval experiment

## What not to do in the first implementation

- do not expose raw `QMD` CLI to bots
- do not index observations yet
- do not include operator scope
- do not attempt cross-tenant support before `tenant_0` works

## Success criteria

The wrapper contract is successful if:

1. it makes `QMD` usable without weakening isolation
2. it keeps canonical memory as truth
3. it is simple enough to implement for `tenant_0`
4. it can evolve into a multi-tenant service later

## Recommended next actions

1. implement the first local wrapper command or service for `tenant_0`
2. add explicit corpus rebuild command
3. run positive and negative retrieval tests before wiring any bot to it
