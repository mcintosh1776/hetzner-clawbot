# Runtime Isolation Plan

## Purpose

This document records the target architecture for moving beyond the current
single-gateway, multi-agent deployment.

Reason:

- Multiple bots are expected to hold high-value secrets.
- `podcast_media` / `Stacks` is expected to hold Nostr signing keys.
- `business` / `Number 5` is expected to gain treasury or money-adjacent
  responsibilities.
- A single shared gateway process is not a strong enough long-term isolation
  boundary for those trust levels.

This plan is intended to survive context loss and compaction. It is the working
record for the next major architecture step.

## Top-priority milestone

Before more bot behavior work lands, extract private agent identity content out
of this public repo.

Reason:

- the real `SOUL` / `AGENT` / `MEMORY` files are part of the product IP
- they should not live in public bootstrap code long-term
- the infrastructure repo should consume a pinned private export, not remain the
  source of truth for agent identity

Contract:

- see [private-agent-pack-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/private-agent-pack-contract.md)

## Current state

Current production shape:

- One public Hetzner node
- One public ingress layer:
  - `nginx`
  - `certbot`
  - Telegram webhook relay
- One shared OpenClaw gateway for control/dashboard duties
- Five same-host private bot runtimes behind ingress:
  - `bob-runtime`
  - `stacks-runtime`
  - `jennifer-runtime`
  - `steve-runtime`
  - `number5-runtime`
- Five Telegram-facing bots:
  - `Bob`
  - `Jennifer`
  - `Steve`
  - `Stacks`
  - `Number 5`

Current strengths:

- Rebuilds are largely automated.
- `/opt` survives rebuilds.
- Telegram ingress and routing are working.
- Private same-host bot runtimes are working.
- OpenRouter defaults are working across the bot fleet.

Current limitation:

- All five bots still share one host and one `openclaw` OS user boundary.
- That is better than the former single shared gateway path, but it is not the
  right permanent boundary for signing keys or treasury authority.

## Target architecture

### Goal

Keep the current Telegram user experience while moving secret-bearing bots into
separate runtime boundaries.

### End-state principles

1. Public bot identities stay stable.
2. Public ingress stays simple.
3. Secret-bearing bots get their own runtime boundary.
4. Inter-bot communication becomes explicit and auditable.
5. Shared-gateway prompt routing stops being the secret boundary.

### Target shape

#### Public ingress layer

Responsibilities:

- `nginx`
- `certbot`
- Telegram webhook routing
- optional lightweight coordination/orchestration entrypoint

Properties:

- internet-facing
- no Nostr private keys
- no treasury signing keys

#### Private bot runtimes

Each high-value bot gets its own runtime:

- `stacks-runtime`
- `treasurer-runtime`
- possibly later:
  - `number5-runtime`
  - `research-runtime`
  - `steve-runtime`

Each runtime should have its own:

- process/container
- config
- state directory
- secret store
- auth profile store
- model/runtime settings as needed

#### Communication model

Preferred model:

- private internal HTTP/RPC between services

Why:

- simplest operating model
- easy to audit
- easy to restrict by host/network policy
- straightforward request/response semantics

Possible later evolution:

- queue/event bus for async workflows

That is optional and should not be phase one.

## User experience constraint

The external UX should remain:

- you can DM each bot directly
- you can use each bot in Telegram groups
- each bot keeps its own Telegram identity

That means:

- one public ingress layer can still receive all Telegram webhooks
- ingress then routes inbound updates to the correct private runtime
- the runtime replies as that same bot identity

This is compatible with runtime isolation.

## Secret-handling model

### Minimum acceptable rule

Do not place high-value signing keys in:

- shared `.env`
- shared Telegram env
- shared LLM env
- shared gateway config

### Better model

Each secret-bearing runtime owns its own:

- key material
- auth profiles
- outbound signing operations

### Stronger model

For the most sensitive cases:

- separate host or separate VM

### Important boundary note

Separate containers on one host are better than one shared gateway process, but
they are not the strongest possible boundary.

If the threat model becomes:

- “a compromised peer bot must not be able to reach this key”

then the correct target is:

- separate runtime
- separate OS/user boundary at minimum
- separate VM for the highest-value keys

## Recommended staged approach

Do not split all bots immediately.

Split by risk class.

### Phase 1

Stabilize current shared system.

Done or in progress:

- automated rebuilds
- Telegram ingress
- multi-agent routing
- OpenRouter default model
- bootstrap trust hardening
- secret exposure reduction

Exit criteria:

- current stack remains reliable for non-key-bearing bots

### Phase 2

Extract `Stacks` first.

Reason:

- Nostr signing keys are the first strong secret boundary requirement already
  on the horizon

Deliverables:

- dedicated `stacks-runtime`
- dedicated config/state/secrets
- Telegram ingress path still preserved as `/telegram/stacks`
- private service interface defined
- working build spec:
  - [stacks-runtime-build-plan.md](/home/mcintosh/repos/hetzner-clawbot/docs/stacks-runtime-build-plan.md)

Exit criteria:

- `Stacks` can receive Telegram work and respond normally
- Nostr secret is no longer in shared gateway scope

### Phase 3

Extract `Treasurer`.

Reason:

- treasury and money movement should not share runtime boundary with general
  conversational bots

Deliverables:

- dedicated `treasurer-runtime`
- dedicated secret and signing path
- explicit approval and audit design for money actions

Exit criteria:

- treasury actions happen only inside the treasurer boundary

### Phase 4

Decide whether `Number 5` and Treasurer are separate.

Decision point:

- if `Number 5` is only conversational/business strategy, keep it separate from
  Treasurer
- if `Number 5` must directly hold financial authority, merge or tightly couple
  with Treasurer runtime

Recommended default:

- keep `Number 5` conversational
- keep Treasurer operational and financially authoritative

### Phase 5

Reassess the rest of the bot fleet.

Possible outcomes:

- keep `Bob`, `Jennifer`, and `Steve` together
- or gradually split them if their tool/secret surface expands

## Milestones and progress markers

### M1: Architecture locked

Definition:

- this document is accepted as the target direction
- no new high-value signing features are added to the shared gateway

Progress marker:

- complete

### M2: Service contract defined

Definition:

- define how ingress forwards to isolated runtimes
- define how isolated runtimes reply
- define internal auth between services

Working document:

- [runtime-service-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-service-contract.md)
- [runtime-migration-inventory.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-migration-inventory.md)

Progress marker:

- complete

### M3: Stacks isolation build

Definition:

- provision and run the first isolated private runtimes behind shared ingress,
  with `Stacks` as the first vertical slice and the rest of the current bot fleet
  following the same contract

Progress marker:

- complete

### M4: Stacks secret migration

Definition:

- move Nostr key handling fully out of shared gateway scope

Progress marker:

- pending

### M5: Treasurer architecture decision

Definition:

- decide runtime placement, signing boundary, and approval model

Progress marker:

- pending

### M6: Treasurer isolation build

Definition:

- build dedicated runtime and secret flow for treasury actions

Progress marker:

- pending

## Decision rules

Use these rules to avoid redesign churn.

1. If a bot needs a signing key, assume it does not belong in the shared
   gateway long-term.
2. If a bot can move money or create externally binding actions, assume it
   deserves its own runtime.
3. Keep public ingress stable even while internal runtimes evolve.
4. Prefer one well-defined migration per risk class over repeated partial
   hardening of the shared gateway.

## What not to do

Avoid:

- adding Nostr private keys to shared env files
- adding treasury secrets to the current shared gateway
- assuming agent-level prompt separation is enough for key isolation
- repeatedly extending the single shared runtime and calling that the final
  architecture

## Immediate next steps

1. Keep batching security hardening on the current shared system.
2. Design the internal service contract for isolated runtimes.
3. Choose whether isolated runtimes start as:
   - separate containers on one host
   - or separate hosts for the highest-risk bots
4. Implement `Stacks` first.
