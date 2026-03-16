# Tenant 0 Implementation Checklist

## Purpose

Turn the tenant-fleet architecture into a concrete implementation sequence for the current deployment, treating the existing Satoshi's Plebs bots as `tenant_0`.

This checklist is intentionally practical.
It is the bridge between architecture and code.

## Reference documents

- [tenant-fleet-architecture.md](/home/mcintosh/repos/hetzner-clawbot/docs/tenant-fleet-architecture.md)
- [tenant-0-naming-and-paths.md](/home/mcintosh/repos/hetzner-clawbot/docs/tenant-0-naming-and-paths.md)
- [memory-schema.md](/home/mcintosh/repos/hetzner-clawbot/docs/memory-schema.md)

## Guiding rule

Do not try to make the whole platform multi-tenant in one leap.

The right move is:

1. formalize `tenant_0`
2. make new code tenant-aware
3. migrate the highest-risk state paths first
4. leave working flows intact unless a migration step clearly improves them

## Success definition

At the end of this phase:

- `tenant_0` is explicitly modeled in config and state
- new state/layout no longer assumes one global tenant forever
- memory has a defined home and schema
- current bots have explicit capability tiers
- proposal/publish/channel flows can be explained in tenant terms

## Phase 1: lock identifiers and ownership

## 1.1 Define first-class ids

Required:

- `tenant_id`
- `bot_id`
- `agent_id`

`tenant_0` mappings:

- `tenant_id = tenant_0`
- `bob -> orchestrator`
- `stacks -> podcast_media`
- `jennifer -> research`
- `steve -> engineering`
- `number5 -> business`

Checklist:

- [ ] document these ids in config conventions
- [ ] stop introducing new code that infers tenant implicitly
- [ ] preserve distinction between public bot id and internal agent id

## 1.2 Define ownership of current resources

Checklist:

- [ ] classify current state paths as tenant-owned, bot-owned, operator-owned, or platform-owned
- [ ] classify current secrets as tenant-owned and bot-owned where relevant
- [ ] classify current repo bindings and channel bindings as tenant-owned resources

## Phase 2: lock capability tiers

## 2.1 Define current bot tiers

Recommended initial mapping:

- `Bob`
  - tier: `proposal_capable`
- `Stacks`
  - tier: `publishing_capable`
  - plus proposal capability
- `Jennifer`
  - tier: `publishing_capable`
  - plus proposal capability
- `Steve`
  - tier: `proposal_capable`
- `Number5`
  - tier: `proposal_capable`

Checklist:

- [ ] write explicit capability matrix for each bot
- [ ] list which bots can publish, sign, propose, or only draft
- [ ] list which bots should remain unprivileged

## 2.2 Define tier enforcement points

Checklist:

- [ ] identify where capability checks belong in runtime code
- [ ] identify where capability checks belong in secret resolution
- [ ] identify where capability checks belong in proposal/publish services

## Phase 3: create tenant-aware path conventions

## 3.1 Introduce tenant-root targets

Target roots:

- `/opt/clawbot/tenants/tenant_0/`
- `/opt/clawbot-root/tenants/tenant_0/`

Checklist:

- [ ] create final target path map for runtime state
- [ ] create final target path map for proposal-service state
- [ ] create final target path map for channel dedupe state
- [ ] create final target path map for repo clones
- [ ] create final target path map for secrets/bootstrap material

## 3.2 Decide migration strategy per path family

For each path family choose:

- hard move
- compatibility shim
- delayed migration

Checklist:

- [ ] runtime state path decision
- [ ] proposal-service path decision
- [ ] Telegram dedupe path decision
- [ ] repo clone path decision
- [ ] root secret path decision

## Phase 4: establish tenant 0 memory layout

## 4.1 Create tenant_0 memory roots

Target paths:

- `/opt/clawbot/tenants/tenant_0/memory/canonical/`
- `/opt/clawbot/tenants/tenant_0/memory/observations/`
- `/opt/clawbot/tenants/tenant_0/memory/retrieval/`
- `/opt/clawbot/tenants/tenant_0/memory/session/`

Checklist:

- [ ] create directory layout design
- [ ] decide owner/mode rules
- [ ] define what service writes each path

## 4.2 Create the first canonical memory entries

Start with a very small set.

Recommended first entries:

- tenant-wide brand/voice guidance
- Stacks durable social tone guidance
- Jennifer durable editorial caution guidance
- operator-visible but bot-hidden review rules if needed

Checklist:

- [ ] write first 3-5 canonical entries for `tenant_0`
- [ ] place them in the schema format from `memory-schema.md`
- [ ] ensure each entry has correct scope and metadata

## 4.3 Define observation workflow

Checklist:

- [ ] define where observational memory files land
- [ ] define who may create them
- [ ] define who may promote them
- [ ] define when they expire or get reviewed

## Phase 5: tenantize current working features

## 5.1 Proposal PR workflow

Checklist:

- [ ] make proposal services conceptually tenant-aware in docs and naming
- [ ] define future tenant-scoped repo root
- [ ] define tenant-aware repo authorization rules
- [ ] ensure no cross-tenant proposal assumptions remain in new code

## 5.2 Telegram/channel routing

Checklist:

- [ ] define tenant-scoped channel state paths
- [ ] define tenant ownership for Telegram bot tokens
- [ ] define how multiple tenant fleets coexist without webhook state collision

## 5.3 Publish/sign flows

Checklist:

- [ ] define which publish/sign flows are tenant-wide services vs bot-specific services
- [ ] document which secrets are tenant-scoped and which are bot-scoped
- [ ] ensure future routing model always includes tenant context

## Phase 6: define the first post-tenant_0 specialist template

## 6.1 Pick one narrow specialist

Recommended examples:

- named YouTube script bot
- named inbox triage bot

Checklist:

- [ ] choose the first new specialist
- [ ] define role and constraints
- [ ] define memory scope
- [ ] define channels
- [ ] define capability tier

## 6.2 Write the bot template

Checklist:

- [ ] write a reusable bot-spec template
- [ ] include name, role, tools, memory, channel, and policy fields
- [ ] ensure future bots are created from templates, not improvisation

## Phase 7: define shared template/config library

## 7.1 Define shared template model

Checklist:

- [ ] define what lives in the shared template library
- [ ] define what gets copied into a tenant fleet versus referenced centrally
- [ ] define what tenants may rename and tune safely

## 7.2 Define initial shared specialist templates

Recommended first templates:

- [ ] YouTube specialist
- [ ] social/media specialist
- [ ] mail/inbox specialist

Success criteria:

- tenants can start from reusable specialist templates instead of hand-building every bot

## Phase 7.5: define structured bot handoffs and work queues

## 7.5.1 Define work-item states

Checklist:

- [ ] define a minimal task state machine for multi-bot work
- [ ] define ownership transfer rules between bots
- [ ] define what Bob must validate before rerouting work

## 7.5.2 Define handoff packet contract

Checklist:

- [ ] define required handoff fields
- [ ] define implementation -> QA handoff rules
- [ ] define QA -> approval or QA -> engineering return path
- [ ] define Bob's validation/routing responsibilities

Success criteria:

- specialist bots can hand work to each other without relying on loose chat memory

## Phase 8: define tenant web control board

## 8.1 Define control board scope

Checklist:

- [ ] define tenant-facing fleet management surface
- [ ] define bot status/configuration views
- [ ] define approvals/history view
- [ ] define template library browsing and copy flow

## 8.2 Define control board first-version priorities

Checklist:

- [ ] define must-have controls for tenant_0
- [ ] define what remains operator-only for now
- [ ] define how tenants will create or tune bots from shared templates

## Phase 8.5: write the operator handbook

## 8.5.1 Define operator runbook scope

Checklist:

- [ ] define the operator’s current responsibilities
- [ ] define common memory/transcript/template commands
- [ ] define approval boundaries and rebuild discipline
- [ ] define current incident/recovery basics

Success criteria:

- the operator has an explicit handbook for current live operations

## Phase 9: choose implementation order

Recommended order:

1. id model and ownership
2. capability tier matrix
3. tenant path conventions
4. memory roots and first canonical entries
5. tenant-aware migration of current state paths
6. first new specialist bot template
7. shared template/config library
8. tenant web control board

## Items that should not slip

These are the highest-value items and should not be deferred if the two-week window is real:

1. explicit `tenant_0` model
2. memory schema acceptance
3. capability tier definitions
4. target tenant-aware path conventions
5. first canonical memory entries
6. post-memory testing harness

## 6. Post-memory testing harness

After the QMD and memory system is in place, add explicit test coverage before broader bot rollout.

- [ ] add wrapper-level retrieval tests for tenant-scoped and bot-scoped queries
- [ ] add negative tests proving one bot cannot retrieve another bot's private memory
- [ ] add negative tests proving one tenant cannot retrieve another tenant's memory
- [ ] add smoke tests for canonical memory update -> rebuild -> embed -> retrieval
- [ ] add regression tests for proposal flow plus memory retrieval coexisting on the same node
- [ ] define a repeatable test corpus for tenant_0 so retrieval quality can be checked after rebuilds
- [ ] document expected search hits for a small set of stable queries
6. shared template library model
7. tenant control board scope

## Items that can wait slightly longer

If time gets tight, these can land just after the two-week window:

- final retrieval engine choice
- full path migration in code
- pooled runtime design
- multi-tenant control plane implementation

## Risks

### 1. Over-design without implementation

Mitigation:

- make at least one real path and one real memory root tenant-aware

### 2. Mixing canonical memory with runtime state

Mitigation:

- keep canonical memory under dedicated directories and schema

### 3. Capability creep

Mitigation:

- lock tier definitions early and apply them to current bots

### 4. Path sprawl

Mitigation:

- define target path conventions before more ad hoc state is added

## Concrete next actions

Recommended immediate sequence:

1. review and accept the tenant and memory docs
2. write the capability-tier matrix for current bots
3. create the first tenant_0 canonical memory files
4. decide the first path family to tenantize in code

## Completion marker

This checklist is complete when:

- `tenant_0` is explicit in design and path conventions
- the current bot fleet has written capability tiers
- canonical memory exists in the new schema
- future implementation work no longer assumes a permanently single-tenant system
