# Stacks Runtime Build Plan

## Purpose

This document defines the first implementation slice for `M3`:

- build `stacks-runtime`
- keep the existing Telegram UX
- move Stacks-specific high-value secrets out of the shared gateway runtime

This is intentionally the first isolated runtime because it is the clearest
high-risk bot boundary currently on the roadmap.

This document now also serves as the template for moving the rest of the
current Telegram bot fleet onto the same private-runtime contract on the same
host before any host-level split.

Related documents:

- [runtime-isolation-plan.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-isolation-plan.md)
- [runtime-service-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-service-contract.md)
- [runtime-migration-inventory.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-migration-inventory.md)

## Goal

Replace the current in-process handling of `Stacks` with:

- one dedicated private runtime
- one explicit ingress-to-runtime hop
- one root-owned Stacks secret path
- no same-host assumptions in the contract

The runtime may begin on the same host, but it must be buildable as a separate
host later without changing the public contract.

## Scope of the first slice

Included:

- internal `stacks-runtime` service
- ingress forwarding from `/telegram/stacks`
- authenticated internal call from ingress to `stacks-runtime`
- structured action response from `stacks-runtime`
- outbound Telegram send still handled by ingress
- Stacks-specific secret resolution path

Implementation status:

- bootstrap wiring is in progress
- first pass targets same-host private HTTP on `127.0.0.1:18921`
- ingress remains responsible for outbound Telegram sends

Not included yet:

- Nostr publishing itself
- separate host deployment
- queue/event bus
- Bob-to-Stacks delegation from another runtime
- richer response shaping beyond the minimal "final reply text only" guardrail

## Current publishing policy

For now, Stacks must run social/Nostr posts past the operator before any public
publish step.

Operationally, that means:

- drafting is allowed
- signing is allowed only through the signer boundary
- publishing is approval-gated

The first implementation should therefore stop at draft and sign support unless
the request explicitly carries operator approval.

## Runtime identity

Runtime id:

- `stacks-runtime`

Public identity:

- `Stacks`
- Telegram bot path: `/telegram/stacks`

Internal agent id:

- `podcast_media`

## Deployment model

### Initial placement

Allowed initial placement:

- separate runtime/container on the same host as ingress

Required property:

- ingress talks to Stacks through a private HTTP interface only

No allowed shortcut:

- no shared file-path dependency between ingress and runtime
- no in-process OpenClaw routing dependency

### Preferred future placement

- separate host

This first slice must not depend on same-host file sharing or loopback-only
coupling that would block that move later.

## Proposed private interface

### Service bind

Initial suggested internal bind:

- `127.0.0.1:18921` if same-host

Future separate-host equivalent:

- `http://stacks-runtime.internal:8080`

The exact host can change. The contract should not.

### Endpoint

- `POST /v1/inbound/telegram`

### Auth

Ingress sends:

- `Authorization: Bearer ${STACKS_INTERNAL_API_TOKEN}`

Token source:

- root-owned Stacks secret store
- or ingress service token store if ingress remains the caller of record

## Public ingress changes required

Ingress must gain a routing table entry for Stacks:

- public bot id: `stacks`
- internal runtime target: `stacks-runtime`
- internal URL:
  - initial: `http://127.0.0.1:18921/v1/inbound/telegram`

Ingress keeps:

- Telegram token for `Stacks`
- Telegram webhook secret validation
- outbound Telegram send logic

Ingress does not hold:

- Nostr signing key

## Stacks runtime responsibilities

`stacks-runtime` should own:

- Stacks persona/prompt
- Stacks session/state
- Stacks auth/profile state
- future Nostr key resolution
- any Stacks-only tool integrations

It should return only structured actions, such as:

- `telegram.sendMessage`
- `telegram.sendTyping`
- later:
  - `audit.note`
  - `delegate.request`

For Nostr-specific work, Stacks should prefer responses like:

- `draft ready for approval`
- `signed artifact prepared`

and should not publish directly until approval is explicit.

## Secret model for Stacks

### Root-owned store

Use:

- `/opt/clawbot-root/secrets/podcast_media.json`

Provider id:

- `agent_podcast_media_root`

### Initial contents

Bootstrap now seeds:

- `internal/apiToken`

Future operator-managed contents may add:

- `nostr/privateKey`
- `nostr/publicKey`

Later expected contents:

```json
{
  "nostr/privateKey": "nsec1...",
  "nostr/publicKey": "npub1...",
  "internal/apiToken": "..."
}
```

### Runtime requirement

`stacks-runtime` must resolve any future signing key through the root-owned
provider path, not from:

- shared `.env`
- shared `telegram.env`
- shared `llm.env`

And even with key material configured:

- `nostr/privateKey` remains sign-only
- public posting still requires operator approval

## Configuration inventory

### Ingress-side config needed

- Stacks runtime URL
- Stacks internal API token
- route mapping from `stacks` to `stacks-runtime`

### Runtime-side config needed

- runtime id: `stacks-runtime`
- agent id: `podcast_media`
- identity name: `Stacks`
- OpenRouter model default
- root secret provider reference
- internal bearer token validation

## Files likely to change during implementation

This is the expected first-pass file list.

### Repo

- `modules/clawbot_server/bootstrap-node-runner.sh`
- `modules/clawbot_server/cloud-init.tftpl`
- `live/prod/fsn1/clawbot/terragrunt.hcl`
- likely one or more new files for runtime routing or service templates

### Node/runtime outputs

- `/opt/clawbot/config/openclaw.json` or ingress equivalent
- `/opt/clawbot-root/secrets/podcast_media.json`
- one dedicated Stacks runtime unit/container definition

## Migration steps

### Step 1

Introduce Stacks runtime without changing Telegram UX.

Meaning:

- `/telegram/stacks` still works
- ingress forwards internally instead of shared in-process routing

### Step 2

Verify ingress-to-Stasks contract.

Success means:

- Telegram webhook arrives
- ingress forwards
- Stacks runtime returns structured action
- ingress sends reply

### Step 3

Move Stacks-only secret usage to runtime-local resolution.

Success means:

- shared gateway no longer needs Stacks signing secrets

### Step 4

Optionally detach to separate host later with no public contract change.

## Success criteria

This slice is done when:

1. `Stacks` still works from Telegram DM/group UX
2. ingress no longer depends on the shared gateway runtime for `Stacks`
3. Stacks secret path is isolated from shared gateway env/config
4. the same ingress contract would still work if `stacks-runtime` moved to a new host

## Rollback plan

Rollback should be simple:

- restore ingress routing for `stacks` to the existing shared runtime
- leave the new runtime disabled or detached

That means the first implementation should avoid destructive replacement of the
current Stacks behavior until the isolated path is proven.

## Immediate next coding target

When implementation begins, the first actual code target should be:

- add a private `stacks-runtime` service that accepts the `POST /v1/inbound/telegram`
  contract and returns a simple `telegram.sendMessage` action

That is the smallest vertical slice that proves the architecture with minimal
risk.
