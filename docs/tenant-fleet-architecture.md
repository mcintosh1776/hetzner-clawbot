# Tenant Fleet Architecture

## Purpose

Define the target architecture for scaling from the current small-bot system to a multi-tenant platform, using the current Satoshi's Plebs bots as `tenant_0`.

This document is not a vague future-state sketch. It is a concrete design target for the next phase of the system.

## Time horizon

- planning horizon: next 2 weeks
- reference tenant: `tenant_0`
- reference fleet: current named bots (`Bob`, `Stacks`, `Jennifer`, `Steve`, `Number5`)

## Core design statement

The platform should become a multi-tenant system where each tenant owns a fleet of named, narrow specialist bots with:

- hard tenant isolation
- bot-scoped memory and policy
- tenant-scoped secrets and channels
- Git-reviewed behavioral improvement loops
- shared infrastructure underneath where reasonable

The external product should feel like named team members.
The internal platform should behave like a secure tenant-aware control plane.

## Non-goals

- one giant general-purpose bot per tenant
- one undifferentiated memory pool shared by all bots
- prompt-only separation between tenants
- direct agent writes to canonical `main`
- one dedicated full runtime stack per bot as the long-term default

## Design principles

### 1. Tenant is the hard boundary

Tenants must not be able to read, write, infer, or affect:

- other tenants' memory
- other tenants' secrets
- other tenants' repos
- other tenants' channels
- other tenants' approvals
- other tenants' bot state

This boundary must be enforced in services and storage, not only in prompts.

### 2. Named specialists, not anonymous utilities

Bots should be externally presented as named team members with stable identity.

Examples:

- `Stacks` for media/promo
- `Jennifer` for research/editorial
- future examples like a named YouTube script bot or inbox triage bot

Naming is part of product value and customer stickiness.

### 3. Narrow scope by default

Each bot should have:

- a narrow role
- a narrow memory slice
- narrow tools
- narrow authority

Broad coordinator bots may exist, but should be exceptions.

### 4. Shared platform, isolated tenants

The platform may share:

- compute
- worker infrastructure
- memory/index infrastructure
- proposal/publish service code
- orchestration code

But it must not share:

- tenant identity
- tenant secrets
- tenant memory namespaces
- tenant channels

### 5. Canonical memory must remain human-auditable

Binary/vector storage may be used for retrieval.
It must not be the only durable truth layer.

Canonical truth should remain text-first and reviewable.

## Current state

Current system characteristics:

- effectively single-tenant
- small fleet of named bots
- heavy per-bot runtime/service wiring
- per-bot Telegram identities
- signer-backed publish flows
- Git-reviewed proposal PR flow for agent-pack changes

This is appropriate for early development and security-sensitive experimentation.
It is not the target steady-state design for 50 tenants / 200 bots.

## Target architecture

## 1. Tenant model

Every important object must carry tenant context.

Minimum identifiers:

- `tenant_id`
- `bot_id`
- `session_id` where relevant

Core tenant-owned resources:

- bot fleet definition
- bot channels and external identities
- bot memory namespaces
- tenant-scoped shared memory
- secrets
- repo bindings
- approval policies

### Tenant scopes

Recommended scopes:

- `tenant/<tenant_id>/shared`
- `tenant/<tenant_id>/bot/<bot_id>`
- `tenant/<tenant_id>/operator`
- `platform/public`

No bot should see `tenant/<other>/...` under any normal circumstance.

## 2. Bot model

Each bot is a named specialist with:

- `bot_id`
- display name
- narrow role
- prompt/identity files
- capability tier
- allowed memory scopes
- allowed channels
- allowed tools

### Capability tiers

Proposed tiers:

- `chat_only`
- `drafting`
- `proposal_capable`
- `publishing_capable`
- `privileged`

Most bots should remain in the lower tiers.
Only a small subset should be able to publish, sign, or open repo proposals.

## 3. Runtime model

### Near-term target

Use one runtime boundary per tenant, not one full stack per bot.

That means:

- tenant-scoped runtime group or container set
- multiple bot identities served within the tenant boundary
- bot-level policy inside the tenant runtime

Why this is the right intermediate step:

- stronger separation than global worker pooling
- less sprawl than one runtime per bot
- clearer tenant isolation for secrets, channels, and memory

### Long-term target

Mixed model:

- shared worker pools for low-risk workloads
- dedicated tenant or bot isolation for high-risk bots

High-risk examples:

- publishing/signing bots
- bots with tenant-specific repo authority
- bots with privileged external access

## 4. Memory model

Memory must be split into 3 layers.

### A. Canonical memory

Purpose:

- durable truth
- reviewed memory
- human-readable knowledge

Format:

- Markdown or structured text with metadata
- Git-reviewable where appropriate

Examples:

- tenant writing preferences
- bot role-specific constraints
- approved durable facts
- operator feedback promoted to long-term memory

### B. Retrieval memory

Purpose:

- semantic recall
- efficient search
- long-horizon conversation continuity

Format:

- local vector database and/or FTS index
- derived from canonical memory and conversation logs

Rules:

- tenant- and bot-scoped namespaces
- rebuildable
- not the only durable truth

### C. Runtime/session state

Purpose:

- short-lived working state
- pending approvals
- open proposal references
- recent conversation summaries

Rules:

- can live on durable disk
- should be replaceable
- should not become canonical truth by accident

## 5. Proposal and behavior-change model

The reviewed PR workflow should remain the standard path for durable bot behavior changes.

Desired pattern:

1. bot proposes change
2. proposal becomes patch PR
3. operator reviews and merges
4. deployment picks up new version later

This should remain tenant-scoped:

- tenant bots can only target tenant-owned repos or repo paths
- no cross-tenant proposal authority

## 6. Secret model

Secrets must be tenant-scoped first, bot-scoped second.

Examples:

- Telegram bot tokens
- Nostr keys
- GitHub App installations
- API keys

Rules:

- no raw secret exposure to model outputs
- resolve only through narrow services
- tenant A must never be able to retrieve tenant B secret material

## 7. Channel model

Each tenant should own its own external channel setup.

Examples:

- Telegram bot(s)
- Nostr account(s)
- mail identities
- YouTube channel integrations

This means the product surface is:

- tenant-specific named bots

not:

- one global shared bot account

## 8. Tenant 0 reference fleet

Use current bots as the first tenant-fleet reference model.

### Suggested `tenant_0` roles

- `Bob`
  - coordinator / operator-facing orchestrator
- `Stacks`
  - media and social promotion
- `Jennifer`
  - research and editorial
- `Steve`
  - engineering
- `Number5`
  - business / operations

This tenant is the proving ground for:

- fleet model
- proposal workflow
- scoped memory
- capability tiers

## Milestones

## Week 1

### Milestone 1: lock the tenant model

Deliverables:

- define `tenant_id` and `bot_id` model in config/state
- define tenant-scoped resource naming rules
- define which current resources are tenant-owned vs bot-owned

Questions to settle:

- exact tenant identifier format
- how current single-tenant paths map to `tenant_0`
- where tenant-scoped config lives

Success criteria:

- no ambiguity about tenant vs bot ownership in future code

### Milestone 2: lock the memory model

Deliverables:

- canonical memory schema
- retrieval memory namespace model
- runtime/session state boundary

Questions to settle:

- Git repo vs `/opt` split for canonical memory
- what gets promoted from session data into canonical memory
- vector index choice and namespace model

Success criteria:

- written decision on canonical/retrieval/session layers

### Milestone 3: lock capability tiers

Deliverables:

- capability tier definitions
- per-bot tier mapping for `tenant_0`

Success criteria:

- each current bot assigned a tier
- publish/proposal/signing authority explicitly classified

## Week 2

### Milestone 4: tenantize current architecture on paper first

Deliverables:

- mapping of current `tenant_0` system into target architecture
- list of current single-tenant assumptions that must be removed

Examples:

- state paths
- secret resolution
- webhook routing
- repo proposal routing

Success criteria:

- clear migration checklist from current model to tenant-aware model

### Milestone 5: implement first tenant-aware config/state layer

Deliverables:

- `tenant_0` naming and path conventions in runtime state
- tenant-aware proposal and channel routing plan
- memory directory/service plan ready for implementation

Success criteria:

- new code work can proceed against a defined tenant-aware structure

### Milestone 6: define the first new named specialist bot spec

Deliverables:

- one narrow bot spec outside the current fleet, for example:
  - named YouTube script bot
  - named inbox triage bot

Spec should include:

- role
- tenant scope
- memory scope
- tools
- channels
- capability tier

Success criteria:

- future expansion is driven by narrow specialist templates, not ad hoc bot creation

## Immediate decisions

These should be treated as decided unless there is a strong reason to reverse them.

1. The system is multi-tenant, not merely many-bot.
2. Tenant is the hard security boundary.
3. Bots are named specialists, not generic utilities.
4. Narrow scope is the default.
5. Canonical memory remains text-first.
6. Retrieval memory may use vector storage, but only as a derived layer.
7. Proposal-driven behavioral changes remain Git-reviewed.
8. Near-term runtime direction is tenant-level isolation, not per-bot isolation for everything.

## Open questions

1. Should canonical memory live in its own private repo or under `/opt` first?
2. Should tenant-level runtime isolation mean one container, one pod, or one grouped service set per tenant?
3. Which bots truly need dedicated isolation even inside a tenant?
4. How should cross-bot collaboration inside one tenant be represented safely?
5. What is the exact first retrieval engine choice for the derived memory layer?

## Recommended next actions

1. review and tighten this document
2. define `tenant_0` naming/path conventions
3. write the memory schema doc next
4. map current bots to capability tiers
5. define the first post-`tenant_0` specialist bot template
