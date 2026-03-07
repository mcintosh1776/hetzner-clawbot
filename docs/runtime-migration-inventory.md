# Runtime Migration Inventory

## Purpose

This document turns the isolation strategy into an execution inventory.

It answers four concrete questions:

1. What runtimes exist in the target architecture?
2. Where can each runtime live?
3. In what order should they migrate?
4. What stays in public ingress versus moving into private runtimes?

This is the working inventory for the move away from the shared multi-agent
runtime.

Related documents:

- [runtime-isolation-plan.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-isolation-plan.md)
- [runtime-service-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-service-contract.md)

## Target runtime inventory

### Public ingress

Runtime id:

- `public-ingress`

Responsibilities:

- TLS termination
- `nginx`
- `certbot`
- Telegram webhook reception
- Telegram webhook verification
- Telegram outbound send
- runtime request routing
- internal service authentication
- audit/event logging for cross-runtime calls

Must not hold:

- Nostr private keys
- treasury signing keys
- agent-specific high-value auth stores

May hold:

- Telegram bot tokens
- internal service tokens

### Bob runtime

Runtime id:

- `bob-runtime`

Public identity:

- `Bob`
- Telegram path: `/telegram/bob`

Internal agent id:

- `orchestrator`

Primary role:

- front-door orchestration
- delegation to specialist/private runtimes
- operator-facing coordination

Default placement:

- same host as ingress initially

Potential later placement:

- separate host if tool surface grows significantly

Secret class:

- low to medium

### Jennifer runtime

Runtime id:

- `jennifer-runtime`

Public identity:

- `Jennifer`
- Telegram path: `/telegram/jennifer`

Internal agent id:

- `research`

Primary role:

- research
- synthesis
- recommendation support

Default placement:

- same host as ingress initially

Potential later placement:

- separate host only if external accounts/secrets become significant

Secret class:

- low to medium

### Steve runtime

Runtime id:

- `steve-runtime`

Public identity:

- `Steve`
- Telegram path: `/telegram/steve`

Internal agent id:

- `engineering`

Primary role:

- engineering support
- code and infrastructure analysis

Default placement:

- same host as ingress initially

Potential later placement:

- separate host if it gains privileged infra tooling or signing responsibilities

Secret class:

- medium

### Stacks runtime

Runtime id:

- `stacks-runtime`

Public identity:

- `Stacks`
- Telegram path: `/telegram/stacks`

Internal agent id:

- `podcast_media`

Primary role:

- podcast/media workflows
- future Nostr publishing/signing

Default placement:

- isolated runtime immediately

Preferred long-term placement:

- separate host

Allowed transitional placement:

- separate container/runtime on same host, but designed with no same-host assumptions

Secret class:

- high

### Number 5 runtime

Runtime id:

- `number5-runtime`

Public identity:

- `Number 5`
- Telegram path: `/telegram/number5`

Internal agent id:

- `business`

Primary role:

- business building
- business operations guidance
- likely caller of future Treasurer workflows

Default placement:

- same host as ingress initially

Potential later placement:

- separate host if it directly acquires financial or signing authority

Secret class:

- medium today
- potentially high later

### Treasurer runtime

Runtime id:

- `treasurer-runtime`

Public identity:

- TBD

Internal agent id:

- TBD

Primary role:

- financial operations
- approvals
- wallet or treasury authority

Default placement:

- separate host

Reason:

- this runtime should be designed from day one as a higher-assurance boundary

Secret class:

- highest

## Placement matrix

### Phase-ready placement

Initial pragmatic target:

- `public-ingress`: host A
- `bob-runtime`: host A
- `jennifer-runtime`: host A
- `steve-runtime`: host A
- `number5-runtime`: host A
- `stacks-runtime`: host A as isolated runtime, but built to move cleanly
- `treasurer-runtime`: not yet implemented

### Preferred end-state placement

- `public-ingress`: host A
- `bob-runtime`: host A
- `jennifer-runtime`: host A or host B if needed later
- `steve-runtime`: host A or host B if needed later
- `number5-runtime`: host A or host B depending on authority level
- `stacks-runtime`: separate host
- `treasurer-runtime`: separate host

## What stays in ingress

Keep these in `public-ingress`:

- public TLS
- Telegram transport
- public webhook paths
- Telegram secret validation
- Telegram token use for inbound/outbound transport
- routing table from public bot identity to internal runtime target
- internal auth tokens for calling private runtimes
- observability for inbound/outbound request ids

Do not move these into private runtimes initially:

- public webhook exposure
- direct public TLS handling

Reason:

- ingress is stable shared infrastructure
- it should remain simple and reusable

## What moves into private runtimes

Each runtime should own:

- its own prompt/runtime config
- its own state
- its own auth/profile files
- its own high-value secrets
- its own tool integrations
- its own policy for high-risk operations

High-value runtime-only assets:

- `Stacks`: Nostr signing keys
- `Treasurer`: treasury/wallet/financial credentials

## Migration order

### Order

1. `Stacks`
2. `Bob`
3. `Jennifer`
4. `Steve`
5. `Number 5`
6. `Treasurer`

### Why this order

#### 1. Stacks first

- highest immediate secret pressure
- clearest isolation justification
- smallest useful vertical slice for proving the architecture

#### 2. Bob second

- Bob is the orchestration front door
- once Stacks is isolated, Bob should stop depending on in-process routing assumptions

#### 3-5. Jennifer, Steve, Number 5

- lower urgency than Stacks
- easier to move after ingress-to-runtime contract is already exercised

#### 6. Treasurer last in sequence, but designed early

- Treasurer should not be built casually inside the shared gateway
- its design should be informed by the Stacks isolation experience
- but the actual runtime can come later if the product need is not immediate

## Migration checkpoints

### C1: ingress routing table externalized

Definition:

- ingress knows runtime targets per bot
- no dependence on shared in-process agent binding for future isolated bots

### C2: Stacks runtime live

Definition:

- Stacks receives normalized requests from ingress
- Stacks returns structured actions
- Telegram UX remains unchanged

### C3: Bob delegates over the service contract

Definition:

- Bob can call another runtime through the internal HTTP contract
- no shared in-process shortcut is required

### C4: general runtime template available

Definition:

- creating a new bot runtime is operationally routine

### C5: Treasurer host profile defined

Definition:

- separate-host baseline for Treasurer is written down before implementation

## Operational rules

1. New high-value secrets do not go into the shared gateway.
2. New bot runtimes must implement the service contract, not invent a one-off API.
3. Same-host placement is allowed only if the contract does not depend on it.
4. Separate-host readiness should be treated as a design requirement for Stacks and Treasurer.

## What this prevents

This inventory is intended to prevent:

- building another shared-gateway special case
- re-arguing the target topology every week
- adding key-bearing bots without a boundary decision
- tying runtime communication to same-host shortcuts

## Immediate execution guidance

When implementation starts:

1. build `stacks-runtime` against [runtime-service-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-service-contract.md)
2. keep Telegram ingress in `public-ingress`
3. make no same-host file-sharing assumptions
4. treat separate-host deployment as a non-breaking later move, not a redesign
