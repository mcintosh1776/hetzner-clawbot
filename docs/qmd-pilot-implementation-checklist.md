# QMD Pilot Implementation Checklist

## Purpose

Turn the `QMD` tenant-isolation pilot into a concrete implementation sequence for `tenant_0`.

This checklist assumes the layered memory model already stands:

- canonical text memory
- retrieval/indexing layer
- session/observation layers

`QMD` is being evaluated only for the retrieval/indexing layer.

## Reference documents

- [memory-schema.md](/home/mcintosh/repos/hetzner-clawbot/docs/memory-schema.md)
- [memory-options-comparison.md](/home/mcintosh/repos/hetzner-clawbot/docs/memory-options-comparison.md)
- [qmd-tenant-isolation-pilot.md](/home/mcintosh/repos/hetzner-clawbot/docs/qmd-tenant-isolation-pilot.md)
- [observation-memory-workflow.md](/home/mcintosh/repos/hetzner-clawbot/docs/observation-memory-workflow.md)

## Pilot goal

Prove that `QMD` can serve as a useful retrieval layer for `tenant_0` while preserving:

- tenant isolation
- bot-private memory boundaries
- text-first canonical truth
- rebuildability

## Success definition

The pilot is successful if:

1. canonical memory remains text-first and inspectable
2. `QMD` retrieval improves relevant recall
3. `Stacks` cannot retrieve `Jennifer` private memory
4. `Jennifer` cannot retrieve `Stacks` private memory
5. the retrieval layer can be deleted and rebuilt without losing truth

## Current status

Implemented and verified for `tenant_0`:

- [x] canonical memory root exists under `/opt/clawbot/tenants/tenant_0/memory/canonical/`
- [x] tenant-local `QMD` home exists under `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`
- [x] one `QMD` index is running per tenant for the pilot
- [x] canonical corpus is indexed and embedded
- [x] bot-scope filtering is enforced through the host wrapper
- [x] `Stacks` can retrieve `Stacks` memory
- [x] `Jennifer` can retrieve `Jennifer` memory
- [x] collection context is seeded for the live `tenant_0` collections

Still pending:

- [ ] formal automated tests
- [ ] direct negative retrieval tests recorded as repeatable checks
- [ ] read-only bot tool integration
- [ ] observation-memory indexing policy beyond canonical-only pilot

## Stage 1: finalize pilot corpus

## 1.1 Canonical corpus

Checklist:

- [x] confirm the initial canonical seed set for `tenant_0`
- [x] decide which files are in the first retrieval corpus
- [x] keep the corpus intentionally small

Recommended first corpus:

- tenant shared brand/voice entry
- `Stacks` canonical entry
- `Jennifer` canonical entry
- `Bob` canonical entry

Optional second wave:

- `Steve`
- `Number5`

## 1.2 Observation corpus policy

Checklist:

- [x] decide whether any observation-memory files are included in the first pilot
- [x] if included, restrict to explicitly approved examples only

Recommendation:

- first pilot should index canonical memory only

## Stage 2: define tenant_0 memory filesystem layout

## 2.1 Canonical path

Checklist:

- [x] choose the actual first filesystem location for canonical memory

Recommended target:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/`

## 2.2 Retrieval path

Checklist:

- [x] define the `QMD` index location

Recommended target:

- `/opt/clawbot/tenants/tenant_0/memory/retrieval/qmd/`

## 2.3 Observation path

Checklist:

- [x] define the first observation-memory location

Recommended target:

- `/opt/clawbot/tenants/tenant_0/memory/observations/`

## Stage 3: establish the first real canonical memory root

Checklist:

- [x] create the canonical directory structure for `tenant_0`
- [x] decide ownership and permissions
- [x] copy or generate the initial canonical seed files into that structure

Suggested structure:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/shared/`
- `/opt/clawbot/tenants/tenant_0/memory/canonical/bots/stacks/`
- `/opt/clawbot/tenants/tenant_0/memory/canonical/bots/jennifer/`
- `/opt/clawbot/tenants/tenant_0/memory/canonical/bots/bob/`

## Stage 4: define `QMD` tenant isolation boundaries

## 4.1 Tenant boundary

Checklist:

- [x] decide that `tenant_0` gets its own `QMD` index
- [x] ensure no other tenant data can enter that index

## 4.2 Bot scope filtering

Checklist:

- [x] define scope labels for indexed docs
- [x] define which scopes each bot may query

Pilot defaults:

- `Stacks`:
  - `tenant/tenant_0/shared`
  - `tenant/tenant_0/bot/stacks`
- `Jennifer`:
  - `tenant/tenant_0/shared`
  - `tenant/tenant_0/bot/jennifer`
- `Bob`:
  - `tenant/tenant_0/shared`
  - `tenant/tenant_0/bot/bob`

## 4.3 Operator scope exclusion

Checklist:

- [x] explicitly exclude operator-private scope from bot retrieval in the first pilot

## Stage 5: define the memory service wrapper

Core rule:

Bots should not query raw `QMD` directly.

Checklist:

- [x] define a thin memory service API
- [x] ensure requests include:
  - `tenant_id`
  - `bot_id`
  - desired purpose
- [x] make the service enforce allowed scopes before returning results

## Stage 6: implement indexing workflow

Checklist:

- [x] define how canonical files are fed into `QMD`
- [x] define how index rebuilds are triggered
- [x] define how index invalidation works when canonical files change

Recommendation:

- start with explicit rebuild, not real-time sync

## Stage 7: define retrieval test cases

## 7.1 Positive tests

Checklist:

- [ ] `Stacks` can retrieve tenant-shared brand voice
- [x] `Stacks` can retrieve his own warmth preference
- [x] `Jennifer` can retrieve her editorial discipline rule

## 7.2 Negative tests

Checklist:

- [ ] `Stacks` cannot retrieve `Jennifer` private canonical memory
- [ ] `Jennifer` cannot retrieve `Stacks` private canonical memory
- [ ] no bot can retrieve operator-private content

## 7.3 Operational tests

Checklist:

- [x] delete and rebuild the index without losing truth
- [x] confirm results are materially the same after rebuild

## Stage 8: define daily consolidation boundary

Checklist:

- [ ] confirm daily consolidation writes to observations, not canonical memory
- [ ] define whether observation indexing is part of the first pilot

Recommendation:

- do not include observation indexing in the first `QMD` pilot
- keep first retrieval corpus canonical-only

## Stage 9: decide rollout path

Recommended rollout:

1. create canonical memory directories
2. load small seed corpus
3. build one tenant_0 `QMD` index
4. add memory service wrapper
5. run positive/negative retrieval tests
6. only then consider expanding corpus size

## Risks

### 1. Treating `QMD` as truth

Mitigation:

- keep canonical files as source of truth

### 2. Bot-private leakage inside tenant_0

Mitigation:

- scope-labeled docs
- memory service filtering

### 3. Overcomplicating the first pilot

Mitigation:

- keep the first corpus very small
- no real-time sync
- no operator/private retrieval in first pass

### 4. Premature observation indexing

Mitigation:

- canonical-only first pilot

## Immediate next actions

1. add explicit negative retrieval checks and capture expected results
2. expose a read-only retrieval tool to one bot only, preferably `Stacks`
3. keep the pilot canonical-only until the read path is stable

1. decide where the first canonical files should live on `/opt`
2. create the tenant_0 canonical memory root
3. define the first `QMD` wrapper/service contract
4. then begin implementation
