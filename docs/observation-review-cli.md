# Observation review CLI

This document describes the first host-side CLI for reviewing and promoting
observation memory in `tenant_0`.

Script:
- [scripts/observation-review.mjs](/home/mcintosh/repos/hetzner-clawbot/scripts/observation-review.mjs)

Host binary after bootstrap:
- `/usr/local/bin/clawbot-observation-review`

## Purpose

The CLI exists to make the observation-memory layer operational.

It provides:
- queue inspection
- single-observation review
- explicit rejection
- explicit promotion into canonical bot memory

It does not:
- auto-promote observations
- infer nuanced memory types from freeform text
- bypass canonical review discipline

## Commands

### List observations

```bash
clawbot-observation-review list tenant_0
clawbot-observation-review list tenant_0 --bot bob
clawbot-observation-review list tenant_0 --status pending_review
```

### Show one observation

```bash
clawbot-observation-review show tenant_0 obs-bob-...
```

### Reject one observation

```bash
clawbot-observation-review reject tenant_0 obs-bob-...
```

This updates:
- `status: rejected`
- `updated_at`

### Promote one observation

```bash
clawbot-observation-review promote tenant_0 obs-bob-...
```

This does two things:

1. writes a canonical bot-memory entry under:
- `/opt/clawbot/tenants/<tenant_id>/memory/canonical/bots/<bot_id>/`

2. updates the observation entry with:
- `status: accepted`
- `promoted_to`
- `promoted_path`
- `updated_at`

## Promotion behavior

The first version is deliberately simple.

Canonical entries are written as:
- `type: note`
- `status: active`
- `source: observation_promotion`

And they preserve:
- `tenant_id`
- `scope`
- `bot_id`
- original observation body

This keeps the workflow usable without pretending the tool can reliably infer
whether freeform text is a preference, policy, fact, or style rule.

## Current limitations

- no batch promotion
- no PR/proposal integration yet
- no canonical indexing trigger by itself
- no automatic expiry handling for stale observations

## Recommended use

Use this CLI after:
- explicit `remember this` requests
- future daily consolidation jobs
- future bot-generated observation candidates

Recommended workflow:

1. list pending observations
2. show the candidate
3. reject obvious noise
4. promote stable useful candidates
5. rebuild retrieval when you want canonical retrieval updated
