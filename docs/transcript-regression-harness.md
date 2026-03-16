# Transcript regression harness

This document describes the executable regression harness for the live `tenant_0`
podcast transcript retrieval pilot.

Script:
- [scripts/test-transcript-pilot.sh](/home/mcintosh/repos/hetzner-clawbot/scripts/test-transcript-pilot.sh)

## Purpose

The harness exists to catch regressions in:
- transcript import from the live Podhome RSS feed
- transcript normalization and chunking
- transcript indexing into tenant-local `QMD`
- `Steve`-only transcript retrieval access
- transcript-backed runtime replies for a known text topic

It is a live-node harness, not a unit test suite.

## What it checks

1. Live transcript import
- clears the current transcript source directory
- imports a bounded live batch from the RSS feed
- verifies imported chunk files were produced

2. Transcript indexing
- runs `clawbot-qmd-tenant rebuild tenant_0 --embed`
- verifies `source-transcripts` is present in the rebuild output

3. Positive transcript retrieval
- `Steve` queries `Cypherpunk Manifesto`
- verifies results come from `qmd://source-transcripts/...`
- verifies the result snippets surface cypherpunk-related transcript content

4. Negative transcript isolation
- `Stacks` runs the same query
- verifies no result comes from `qmd://source-transcripts/...`

5. End-to-end runtime behavior
- `Steve` answers:
  - `what do you remember about the Cypherpunk Manifesto from memory`
- verifies the runtime reply includes transcript-backed content

## Usage

Run from the repo root:

```bash
scripts/test-transcript-pilot.sh
```

Optional overrides:

```bash
HOST=91.107.207.3 TENANT_ID=tenant_0 IMPORT_LIMIT=10 scripts/test-transcript-pilot.sh
```

## Current scope

This harness is intentionally narrow.

It proves:
- transcript import works
- transcript indexing works
- `Steve` can query transcript material
- non-`Steve` bots cannot retrieve transcript results

It does not yet prove:
- numeric transcript queries like `20,000,000 Bitcoin`
- guest extraction quality across varied episodes
- bulk transcript import performance beyond the bounded pilot batch

## When to run it

Run this harness after changes to:
- [scripts/import-podcast-transcripts.mjs](/home/mcintosh/repos/hetzner-clawbot/scripts/import-podcast-transcripts.mjs)
- [scripts/qmd-tenant-wrapper.mjs](/home/mcintosh/repos/hetzner-clawbot/scripts/qmd-tenant-wrapper.mjs)
- [modules/clawbot_server/bootstrap-node-runner.sh](/home/mcintosh/repos/hetzner-clawbot/modules/clawbot_server/bootstrap-node-runner.sh)
- transcript metadata extraction
- transcript access policy
