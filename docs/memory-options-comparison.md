# Memory Options Comparison

## Purpose

Compare the most relevant current memory options against the architecture being designed for `tenant_0` and the future multi-tenant fleet platform.

This document is not trying to crown a single winner for "memory."
It compares tools by layer:

- canonical truth
- retrieval/indexing
- conversation continuity

## Options reviewed

- text-first canonical memory layer
- `QMD`
- `memory-lancedb`
- `lossless-claw`

## Architectural requirement

The platform needs three different things:

1. canonical durable truth
2. retrieval/indexing over durable knowledge
3. conversation continuity over long sessions

One tool is unlikely to be ideal for all three.

## Summary recommendation

Best current direction:

- canonical truth:
  - text-first memory files
- retrieval/indexing:
  - seriously evaluate `QMD`
- conversation continuity:
  - evaluate `lossless-claw` or similar context engine separately

That is the cleanest layered design.

## Option 1: text-first canonical memory

## What it is

A tenant- and bot-scoped set of structured text files, likely Markdown with metadata.

Examples:

- durable tenant preferences
- bot-specific style rules
- approved long-term facts
- operator-reviewed lessons

## Strengths

- human-readable
- Git-reviewable if desired
- easy to audit
- easy to diff
- easy to repair
- portable across tooling changes
- naturally fits tenant and bot scoping

## Weaknesses

- not enough by itself for rich retrieval at scale
- needs an indexing/search layer for semantic recall
- can become unwieldy without clear schema

## Best fit

- canonical truth layer

## Recommendation

Required.
This should exist regardless of which retrieval or continuity system is chosen.

## Option 2: QMD

## What it is

`QMD` is a local-first search and retrieval engine designed around Markdown and local knowledge.

Current OpenClaw docs describe `memory.backend = "qmd"` as an experimental memory backend that swaps the built-in SQLite indexer for a local sidecar with hybrid retrieval.

## Relevant characteristics

- local-first
- Markdown source-of-truth friendly
- hybrid retrieval:
  - keyword
  - vector
  - reranking
- integrates with current OpenClaw memory direction

## Strengths

- best current alignment with a text-first architecture
- retrieval layer stays conceptually separate from canonical files
- local operation fits your preference for privacy and control
- good fit for tenant/bot namespacing in principle
- avoids binary-only truth model

## Weaknesses

- still marked experimental in current OpenClaw documentation
- operational behavior at your scale is not yet proven
- multi-tenant discipline will still have to be enforced by your platform design
- likely needs careful namespace and storage planning

## Best fit

- retrieval/indexing layer

## Recommendation

Strong candidate for the first retrieval pilot.
Do not treat it as canonical truth.

## Option 3: memory-lancedb

## What it is

An OpenClaw memory plugin path built around LanceDB.

This is closer to a vector-store-oriented retrieval backend than a text-first memory model.

## Strengths

- likely more straightforward if the goal is vector retrieval quickly
- fits familiar “vector DB backend” thinking
- part of the current OpenClaw plugin landscape

## Weaknesses

- less naturally aligned with your desire for text-first canonical memory
- easier to drift toward “database as truth”
- may be harder to inspect and reason about operationally
- less appealing for the audit/debug discipline you want

## Best fit

- retrieval backend if you choose a more vector-forward design

## Recommendation

Viable, but not my first recommendation for your architecture.
Your goals point more toward `QMD` plus canonical text memory than toward a vector-first memory center.

## Option 4: lossless-claw

## What it is

A context-engine approach for preserving and compressing long conversation history instead of relying on a shallow sliding window.

This is conversation-memory infrastructure, not canonical memory.

## Strengths

- directly addresses long session continuity
- better than losing conversation context entirely
- useful for named bots that build working continuity with owners
- conceptually separate from long-term durable truth

## Weaknesses

- not a replacement for canonical memory
- not a great source of reviewed truth
- stored data is not the same kind of inspectable durable memory you want
- still needs tenancy, scope, and retention design around it

## Best fit

- conversation continuity layer

## Recommendation

Worth evaluating, but only as a context/session layer.
Do not confuse it with your canonical memory system.

## Comparison by layer

| Layer | Best fit now | Why |
| --- | --- | --- |
| Canonical truth | text-first memory files | human-readable, reviewable, portable |
| Retrieval/indexing | QMD | local, Markdown-friendly, hybrid retrieval |
| Conversation continuity | lossless-claw | solves long chat continuity better than static retrieval alone |

## Comparison by your stated priorities

## Auditability

Best:

- text-first canonical memory

Weakest:

- pure binary/vector-first solutions

## Tenant isolation

Best if designed correctly:

- text-first canonical memory plus explicit namespaces
- QMD with strict tenant/bot storage namespaces

Not solved automatically by any option:

- tenant isolation

That must be enforced by your own architecture.

## Scale to many bots

Best:

- shared retrieval infrastructure with tenant/bot namespaces
- canonical text layer independent of retrieval engine choice

Risky if overused:

- per-bot isolated heavy memory stacks

## Debuggability

Best:

- text-first canonical memory

Good:

- QMD if treated as derived index

Weaker:

- vector-first or binary-first systems as primary truth

## Product continuity

Best blend:

- text-first canonical memory
- plus `lossless-claw`-style continuity if needed

Reason:

- one preserves durable learned rules
- the other preserves working conversation continuity

## Recommended architecture for tenant_0

## Layer A: canonical truth

Use:

- text-first canonical memory files under the tenant-aware memory layout

Do first:

- create first real canonical entries for `tenant_0`

## Layer B: retrieval pilot

Pilot:

- `QMD`

Reason:

- most aligned with your desire to keep Markdown/text as truth
- fits the current OpenClaw direction well enough to test seriously

## Layer C: conversation continuity pilot

Evaluate separately:

- `lossless-claw`

Reason:

- useful if named bots are meant to sustain rich owner relationships over long chats
- solves a different problem than retrieval over curated memory

## What I would not do

1. I would not choose one binary/vector system and call the problem solved.
2. I would not let conversation logs become the only long-term truth.
3. I would not delay canonical memory just because retrieval options are evolving.
4. I would not force one tool to solve all layers.

## Immediate decision recommendation

If I were choosing today for your system:

1. canonical memory:
   - yes, build now
2. retrieval pilot:
   - test `QMD`
3. continuity pilot:
   - keep `lossless-claw` in scope, but separate from the canonical-memory decision

## Next actions

1. accept the layered memory model
2. create first canonical memory entries for `tenant_0`
3. write a `QMD pilot plan`
4. later, write a `lossless-claw continuity pilot plan`
