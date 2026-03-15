# Memory regression harness

This document describes the first executable regression harness for the live `tenant_0` memory pilot.

Script:
- [scripts/test-memory-pilot.sh](/home/mcintosh/repos/hetzner-clawbot/scripts/test-memory-pilot.sh)

## Purpose

The harness exists to catch regressions in:
- tenant-local `QMD` status and rebuild flow
- bot-scope isolation inside `tenant_0`
- read-only memory retrieval for the full current fleet:
  - `Bob`
  - `Stacks`
  - `Jennifer`
  - `Steve`
  - `Number5`

It is a live-node harness, not a unit test suite.

## What it checks

1. `clawbot-qmd-tenant status tenant_0`
- verifies the expected collections exist:
  - `shared`
  - `bot-stacks`
  - `bot-jennifer`

2. `clawbot-qmd-tenant rebuild tenant_0 --embed`
- verifies the wrapper rebuild path still succeeds

3. Positive scoped wrapper queries
- `Bob` can retrieve `bob-coordination-boundaries-001`
- `Stacks` can retrieve `stacks-social-warmth-001`
- `Jennifer` can retrieve `jennifer-editorial-discipline-001`
- `Steve` can retrieve `steve-engineering-discipline-001`
- `Number5` can retrieve `number5-business-boundaries-001`

4. Negative scoped wrapper queries
- `Stacks` cannot retrieve `Jennifer` bot-private memory
- `Jennifer` cannot retrieve `Stacks` bot-private memory
- `Steve` cannot retrieve `Number5` bot-private memory
- `Number5` cannot retrieve `Steve` bot-private memory

The negative checks assert that no result file comes from the other bot's private
collection. They do not require an empty result set, because scoped semantic
search can still legitimately return same-bot or shared-memory hits.

5. Runtime memory services
- `clawbot-bob-memory.service` is active
- `clawbot-stacks-memory.service` is active
- `clawbot-jennifer-memory.service` is active
- `clawbot-steve-memory.service` is active
- `clawbot-number5-memory.service` is active

6. End-to-end runtime lookup behavior
- `Bob` answers a natural-language memory question from memory
- `Stacks` answers a natural-language memory question from memory
- `Jennifer` answers a natural-language memory question from memory
- `Steve` answers a natural-language memory question from memory
- `Number5` answers a natural-language memory question from memory

## Usage

Run from the repo root:

```bash
scripts/test-memory-pilot.sh
```

Optional overrides:

```bash
HOST=91.107.207.3 TENANT_ID=tenant_0 scripts/test-memory-pilot.sh
```

## Current limitations

This first harness does not yet prove cross-tenant isolation because only `tenant_0` is populated live.

So today it proves:
- bot isolation within `tenant_0`
- correct tenant-local retrieval wiring for `tenant_0`

Later, once a second tenant exists, the harness should grow a second stage for:
- true tenant-vs-tenant negative retrieval checks
- tenant-specific runtime memory lookups

## When to run it

Run this harness after changes to:
- [modules/clawbot_server/bootstrap-node-runner.sh](/home/mcintosh/repos/hetzner-clawbot/modules/clawbot_server/bootstrap-node-runner.sh)
- [scripts/qmd-tenant-wrapper.mjs](/home/mcintosh/repos/hetzner-clawbot/scripts/qmd-tenant-wrapper.mjs)
- memory-service runtime wiring
- canonical memory seed layout
- `QMD` install or rebuild behavior
