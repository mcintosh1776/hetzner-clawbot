# Capability Tier Matrix

## Purpose

Define explicit capability tiers for the current `tenant_0` fleet and map each existing bot to a clear authority profile.

This document exists to stop capability creep and to give the runtime architecture a concrete policy target.

## Reference tenant

- `tenant_id = tenant_0`

## Reference fleet

- `Bob`
- `Stacks`
- `Jennifer`
- `Steve`
- `Number5`

## Design rule

Bots should only have the authority required for their role.

The default should be:

- narrower authority
- fewer tools
- less cross-domain access

Not:

- broad authority by convenience

## Tier definitions

## Tier 1: `chat_only`

Purpose:

- converse
- answer questions
- provide reasoning and suggestions

Allowed:

- normal conversation
- tenant-scoped retrieval if configured

Not allowed:

- create publishable drafts
- publish
- sign
- open proposal PRs
- touch secrets directly

## Tier 2: `drafting`

Purpose:

- create usable drafts for human review

Allowed:

- draft content
- revise content
- prepare structured outputs for review

Not allowed:

- publish directly
- sign directly
- open PRs unless separately elevated

## Tier 3: `proposal_capable`

Purpose:

- propose durable behavior or configuration changes through review

Allowed:

- draft proposal previews
- open reviewable PRs against allowed repos/paths
- revise proposed changes before approval

Not allowed:

- merge PRs
- write directly to protected branches
- change repos outside allowed tenant scope

## Tier 4: `publishing_capable`

Purpose:

- publish approved external content

Allowed:

- draft publishable content
- revise content
- publish after explicit operator approval
- use signer/publish service where configured

Not allowed:

- publish without approval
- broaden publishing scope outside configured channels

## Tier 5: `privileged`

Purpose:

- access higher-risk or more sensitive workflows

Possible examples:

- coordination across multiple specialists
- higher-trust internal control functions
- access to tenant-sensitive workflow orchestration

Important:

- `privileged` does not mean unrestricted
- even privileged bots should remain tenant-scoped and policy-limited

## Capability dimensions

Each bot should be judged across these dimensions:

- conversation
- drafting
- proposal PRs
- publish after approval
- signing via service
- secret-bearing integrations
- cross-bot coordination
- tenant-shared memory access
- operator-private memory access

## Capability matrix

## Bob

- public bot id: `bob`
- internal agent id: `orchestrator`
- recommended primary tier: `proposal_capable`

### Allowed

- operator-facing conversation
- coordination and escalation
- drafting internal guidance and task framing
- proposing repo changes within allowed tenant-owned scope
- broad tenant-shared memory access where policy permits

### Not allowed by default

- direct public publishing
- direct Nostr signing/publishing unless explicitly added later
- reading operator-private memory unless deliberately granted

### Notes

Bob is the closest thing to a coordinator.
That does not mean Bob should become a superuser.

## Stacks

- public bot id: `stacks`
- internal agent id: `podcast_media`
- recommended primary tier: `publishing_capable`
- secondary capability: `proposal_capable`

### Allowed

- draft media/social content
- revise public-facing content
- publish approved Nostr posts
- publish approved Nostr profile updates
- open reviewed PRs for his own agent-pack guidance
- read his bot scope plus allowed tenant-shared memory

### Not allowed

- publish without approval
- propose repo changes outside allowed tenant-owned paths
- access unrelated bot-private memory by default

### Notes

Stacks is a model example of a narrow specialist with both publish and proposal authority.

## Jennifer

- public bot id: `jennifer`
- internal agent id: `research`
- recommended primary tier: `publishing_capable`
- secondary capability: `proposal_capable`

### Allowed

- draft editorial/research-facing public content
- revise content
- publish approved Nostr posts
- publish approved Nostr profile updates
- open reviewed PRs for her own guidance files
- read her bot scope plus allowed tenant-shared memory

### Not allowed

- publish without approval
- edit unrelated repos/paths
- access unrelated bot-private memory by default

### Notes

Jennifer should remain narrower than a general “content bot.”
Her authority should stay tied to editorial/research work.

## Steve

- public bot id: `steve`
- internal agent id: `engineering`
- recommended primary tier: `proposal_capable`

### Allowed

- discuss engineering work
- draft plans, code suggestions, and implementation proposals
- open reviewed PRs for his own guidance/config within allowed tenant scope
- read engineering-specific memory plus allowed tenant-shared memory

### Not allowed by default

- direct public publishing
- signing/publishing authority
- broad secret access

### Notes

Steve is exactly the kind of bot that should stay narrow and useful.
He can help build things without inheriting broad outbound authority.

## Number5

- public bot id: `number5`
- internal agent id: `business`
- recommended primary tier: `proposal_capable`

### Allowed

- business/ops conversation and drafting
- propose reviewed changes to his guidance files
- read business-specific memory plus allowed tenant-shared memory

### Not allowed by default

- direct public publishing
- direct signing
- cross-tenant anything

### Notes

Number5 should remain a business specialist, not a general operator with broad powers.

## Effective authority table

| Bot | Primary Tier | Draft | Proposal PR | Publish After Approval | Sign Service | Coordinator Role |
| --- | --- | --- | --- | --- | --- | --- |
| Bob | proposal_capable | yes | yes | no | no | limited |
| Stacks | publishing_capable | yes | yes | yes | yes via service | no |
| Jennifer | publishing_capable | yes | yes | yes | yes via service | no |
| Steve | proposal_capable | yes | yes | no | no | no |
| Number5 | proposal_capable | yes | yes | no | no | no |

## Memory access guidance by bot

## Bob

Recommended access:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/bob`

Possible future elevated access:

- mediated visibility into other bot summaries, not raw bot-private memory

## Stacks

Recommended access:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/stacks`

## Jennifer

Recommended access:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/jennifer`

## Steve

Recommended access:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/steve`

## Number5

Recommended access:

- `tenant/tenant_0/shared`
- `tenant/tenant_0/bot/number5`

## Operator-private memory rule

Default:

- no bot gets automatic access to `tenant/tenant_0/operator`

If exceptions exist later, they should be explicit and narrow.

## Service implications

The runtime and service layer should eventually enforce:

- proposal service only for `proposal_capable` and above
- publish service only for `publishing_capable` and above
- signer service only for bots explicitly configured for it
- no service authorization based only on bot name conventions

## Immediate decisions

Treat these as current policy defaults:

1. `Stacks` and `Jennifer` are both `publishing_capable` and `proposal_capable`.
2. `Bob`, `Steve`, and `Number5` are `proposal_capable`, not publishing bots by default.
3. No current bot is a broad unrestricted privileged superuser.
4. Operator-private memory is not readable by bots by default.
5. Proposal authority remains tenant-scoped and path-limited.

## Open questions

1. Should Bob eventually become a higher-trust coordinator tier with mediated cross-bot visibility?
2. Which future bots, if any, should receive direct mail/channel authority?
3. Which capabilities should require dedicated runtime isolation even inside a tenant?

## Recommended next actions

1. accept this matrix as the current authority baseline
2. reflect these tiers in runtime/service config over time
3. use these tiers when defining the first new specialist bot
