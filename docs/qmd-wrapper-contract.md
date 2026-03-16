# QMD Wrapper Contract

## Purpose

Define the implemented `QMD` wrapper contract for the live `tenant_0` pilot.

This document answers:

- where the live `QMD` data lives
- what the current wrapper command does
- how tenant and bot scope are enforced
- what remains before bot-side tool integration

## Current live artifacts

Implemented on the node:

- `qmd`
- `/usr/local/bin/clawbot-qmd-tenant`

Live tenant roots:

- canonical memory:
  - `/opt/clawbot/tenants/tenant_0/memory/canonical/`
- retrieval root:
  - `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`

## Scope

Reference tenant:

- `tenant_0`

Reference use:

- retrieval over canonical memory only

Still out of scope:

- observation indexing
- cross-tenant operation
- direct bot access to raw `QMD`
- automatic canonical writes
- bot write access to memory through the wrapper

## Core rule

Bots do not query `QMD` directly.

The platform uses a wrapper that enforces:

- `tenant_id`
- `bot_id`
- allowed collections

Then the wrapper talks to `QMD`.

## Storage layout

## Canonical source files

Live root:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/`

Live indexed collections:

- `shared`
- `bot-bob`
- `bot-jennifer`
- `bot-number5`
- `bot-stacks`
- `bot-steve`

## QMD home/index root

Live location:

- `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`

Live `QMD` home:

- `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/home/`

## One index per tenant

Current pilot model:

- one `QMD` home/index per tenant

Not:

- one global index for all tenants
- one per-bot index by default

Reason:

- strong tenant separation
- simpler operations
- avoids premature per-bot index sprawl

## Scope model inside the tenant

Supported scopes for `tenant_0`:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/bob`
- `tenant/tenant_0/bot/stacks`
- `tenant/tenant_0/bot/jennifer`
- `tenant/tenant_0/bot/steve`
- `tenant/tenant_0/bot/number5`

Excluded from the current pilot:

- `tenant/tenant_0/operator`

## Implemented wrapper command contract

Current commands:

- `clawbot-qmd-tenant status <tenant-id>`
- `clawbot-qmd-tenant rebuild <tenant-id> [--embed]`
- `clawbot-qmd-tenant query <tenant-id> <bot-id> <query...>`

### `status`

Purpose:

- register collections if needed
- ensure collection context is present
- report current index/collection health

Current behavior:

- runs `qmd status --json`
- returns:
  - tenant id
  - retrieval root
  - collection names
  - raw status text/json

### `rebuild`

Purpose:

- re-index canonical files
- optionally refresh embeddings

Current behavior:

- runs:
  - `qmd update --json`
  - optionally `qmd embed --json`

### `query`

Purpose:

- perform read-only scoped retrieval for one bot

Current behavior:

- uses:
  - `qmd search <query> --json -n 5 -c <collection> ...`
- result is limited to:
  - `shared`
  - `bot-<bot_id>`

## Allowed collections by bot

## Bob

- `shared`
- `bot-bob`

## Stacks

- `shared`
- `bot-stacks`

## Jennifer

- `shared`
- `bot-jennifer`

## Steve

- `shared`
- `bot-steve`

## Number5

- `shared`
- `bot-number5`

## Collection context contract

The wrapper seeds one collection-level context summary per collection.

Current seeded contexts:

- `shared`
  - tenant-wide brand voice and shared operating guidance
- `bot-bob`
  - coordination boundaries and escalation
- `bot-stacks`
  - warmer friendlier media tone, avoid robotic copy and hype
- `bot-jennifer`
  - editorial discipline, evidence-minded framing, avoid marketing tone
- `bot-steve`
  - pragmatic engineering, small reviewable changes, avoid rewrites
- `bot-number5`
  - business framing, operations thinking, structured proposals

## Request contract

The current wrapper is a host command, not an HTTP service.

Future service shape should still look like:

```json
{
  "tenantId": "tenant_0",
  "botId": "stacks",
  "query": "warmer social tone for audience-facing posts",
  "purpose": "style_recall",
  "maxResults": 5
}
```

Required future fields:

- `tenantId`
- `botId`
- `query`

Optional future fields:

- `purpose`
- `maxResults`
- `scopeHint`

## Response contract

Current wrapper response shape:

```json
{
  "ok": true,
  "tenantId": "tenant_0",
  "botId": "stacks",
  "query": "warmer friendlier tone",
  "allowedCollections": [
    "shared",
    "bot-stacks"
  ],
  "retrievalRoot": "/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd",
  "results": [
    {
      "docid": "#d5017c",
      "score": 0.86,
      "file": "qmd://bot-stacks/stacks-social-warmth-001.md",
      "title": "stacks-social-warmth-001",
      "context": "Stacks media and social tone memory...",
      "snippet": "Stacks should write with a warmer and friendlier tone..."
    }
  ]
}
```

Current response fields:

- `ok`
- `tenantId`
- `botId`
- `query`
- `allowedCollections`
- `retrievalRoot`
- `results`

Current result fields come from `QMD`:

- `docid`
- `score`
- `file`
- `title`
- optional `context`
- `snippet`

## Indexing contract

Current corpus:

- canonical memory only

Current live files include:

- shared brand voice
- Bob coordination boundaries
- Stacks social warmth
- Jennifer editorial discipline
- Steve engineering discipline
- Number5 business boundaries

Current refresh model:

- explicit rebuild

Current rebuild rule:

- deleting the tenant retrieval index must not lose truth
- canonical files remain the source of truth

## Security model

Hard boundaries currently enforced:

- no cross-tenant retrieval
- no cross-bot private retrieval by default
- no operator-private retrieval

Things the wrapper does not trust:

- caller-supplied filesystem paths
- caller-supplied scope widening
- caller-supplied tenant switching

## What is now proven

The live pilot has proven:

1. tenant-local `QMD` install works
2. canonical memory can be indexed and embedded
3. bot-scope filtering works
4. `Stacks` retrieval works for `Stacks` memory
5. `Jennifer` retrieval works for `Jennifer` memory
6. collection context is present and returned in results

## What is still pending

- explicit negative retrieval checks captured as repeatable tests
- a read-only bot tool that calls this wrapper or successor service
- observation-memory policy beyond canonical-only pilot
- broader tenant rollout beyond `tenant_0`

## Recommended next actions

1. add repeatable negative retrieval tests
2. expose a read-only retrieval tool to one bot only
3. start with `Stacks`
4. keep write paths out of scope until retrieval behavior is stable
