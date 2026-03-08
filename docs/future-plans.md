# Clawbot Future Plans

## Purpose

This document is the working outline for the next phase of the project after the
`v0.7.23` Telegram/OpenClaw automation milestone.

It separates:

- immediate stabilization work
- medium-term architecture cleanup
- security hardening and audit work
- possible product additions such as a treasurer bot

## Current baseline

The current production baseline is:

- Hetzner `fsn1` production stack
- preserved `/opt` volume across rebuilds
- OpenClaw in rootless Podman
- `nginx` + `certbot` for Telegram webhook ingress
- 5 Telegram bot accounts routed to 5 explicit OpenClaw agents
- default model path set to `openrouter/auto`

The next rebuild should verify that the latest bootstrap changes also render:

- dashboard-friendly agent identities:
  - `Bob`
  - `Jennifer`
  - `Steve`
  - `Stacks`
  - `Number 5`

## Phase 1: immediate stabilization

### Goal

Make the current production shape boring and repeatable.

### Tasks

1. Rebuild from current `main` and verify:
   - bootstrap completes cleanly
   - 5 Telegram bindings are present
   - `openrouter/auto` is the effective default model
   - dashboard shows the friendly agent names
   - `bob`, `jennifer`, and `stacks` all reply after rebuild

2. Cut a release tag only after the rebuild proves the bootstrap-generated
   identity metadata.

3. Reduce manual post-bootstrap steps where possible:
   - verify whether Telegram webhook registration can be made fully declarative
   - keep manual steps documented if Bot API registration must remain operator-driven

## Phase 2: agent architecture cleanup

### Goal

Move from a pragmatic working integration to a cleaner, more standard agent layout.

### Current issue

Agent identity and routing are split across:

- `agent-fleet.yaml`
- specialist markdown prompt files
- generated `openclaw.json`
- OpenClaw runtime state under `.openclaw`

This works, but it is not a single-source-of-truth design.

### Tasks

1. Decide on a canonical agent-definition source.
   Options:
   - keep `agent-fleet.yaml` as the canonical durable source
   - move toward a more OpenClaw-native agent declaration format

2. Generate more of `openclaw.json` from the canonical source:
   - agent ids
   - identity/display names
   - Telegram account bindings
   - role/prompt file mapping

3. Clarify the role of the specialist markdown files:
   - persona only
   - persona + policy
   - persona + policy + routing metadata

4. Decide what to do with the legacy `main` agent state:
   - preserve for compatibility
   - migrate and retire
   - explicitly document it as historical runtime residue

## Phase 3: product and bot expansion

### Goal

Add new specialists without increasing operational confusion.

### Candidate: treasurer bot

Potential treasurer bot scope:

- treasury summaries
- wallet balance reporting
- expense tracking and categorization
- cashflow questions
- draft reporting for human approval

### Preconditions before adding a treasurer bot

1. The current 5-bot production setup must be stable across rebuilds.
2. Canonical agent-definition flow should be clearer than it is now.
3. Security boundaries for financial data must be documented first.

### Treasurer bot design questions

1. What systems would it access?
   - spreadsheets
   - accounting exports
   - wallet software
   - exchange APIs
   - bank-adjacent systems

2. What actions are read-only versus write-capable?

3. Would the bot operate:
   - as an advisor only
   - or with any execution authority

4. What secrets would it require, and where would they live?

## Phase 3.5: memory system upgrade

### Goal

Define and implement a stronger long-term memory approach before the bot fleet grows
much further.

### Why this matters

The current setup is operational, but memory is still relatively implicit and tied
to OpenClaw runtime state. That is probably not enough if the bots are expected to:

- maintain durable context across longer time horizons
- share structured knowledge safely
- support richer recall for research, business, or treasury workflows
- avoid fragile prompt-only personality/state behavior

### Candidate directions

1. QMD-based memory
   - durable markdown-backed knowledge with stronger structure
   - easier human inspection and editing
   - potentially a good fit for repo-managed operational memory

2. OpenClaw-native memory extensions
   - lower integration risk if the platform’s memory model is improving quickly
   - may reduce custom glue code

3. Hybrid design
   - structured human-owned memory in QMD or markdown
   - runtime retrieval/indexing through OpenClaw memory tooling

### Design questions

1. What kinds of memory are needed?
   - operator profile and preferences
   - project history
   - bot-specific persona memory
   - operational runbooks
   - domain knowledge
   - conversation summaries

2. What should be durable versus ephemeral?

3. What should be shared across bots versus isolated per bot?

4. What needs human review before becoming durable memory?

5. What belongs in git-tracked files versus `/opt` runtime state?

### Evaluation criteria

1. Human readability and editability
2. Durable rebuild-safe storage model
3. Compatibility with OpenClaw retrieval/indexing
4. Isolation boundaries between bots
5. Ease of backup and audit
6. Risk of prompt drift or stale memory pollution

### Proposed execution

1. Survey realistic options:
   - QMD
   - current OpenClaw memory model
   - hybrid file-backed approaches

2. Pick one small pilot:
   - likely a single shared operational memory set or one specialist bot

3. Define storage contract:
   - repo-tracked
   - `/opt` persisted
   - generated/indexed artifacts

4. Test rebuild behavior and retrieval quality before broader rollout.

## Phase 4: observability and operability

### Goal

Make future debugging faster and less dependent on ad hoc log spelunking.

### Tasks

1. Improve operator-facing health checks:
   - webhook relay health
   - OpenClaw agent/routing health
   - model/provider health
   - Telegram registration drift detection

2. Add clearer bootstrap summaries:
   - final routing summary
   - final model summary
   - final webhook registration checklist

3. Improve recovery documentation:
   - rebuild steps
   - post-bootstrap checks
   - how to verify the active agent bindings
   - how to verify the active model/provider configuration

## Phase 5: security audit and hardening

### Goal

Audit the current repo and running design for obvious security weaknesses, then
close the high-value ones first.

### Current priority order

For the current phase, the preferred order is:

1. Fix bootstrap runner trust:
   - stop treating a mutable remote `main` branch as trusted root bootstrap code
   - stop treating the cached runner under persisted storage as implicitly trusted

2. Remove the gateway token from cloud-init/user-data:
   - avoid rendering it into Terraform-managed bootstrap payloads
   - keep the durable on-node copy under `/opt` as the primary source of truth

3. Reduce secret reachability from the main gateway container:
   - split secret-bearing files from broad writable config where possible
   - prefer narrower and read-only secret mounts

4. Defer SSH/root/sudo tightening until later:
   - keep the current `mcintosh` operational admin path for now
   - revisit root SSH and broad sudo only after the current platform is calmer

This is a conscious sequencing decision, not a claim that the deferred item is low risk.

### Audit tracks

1. Secrets handling
   - ensure no secrets are committed
   - check env-file handling
   - check bootstrap rendering paths
   - confirm secret placeholders are not accidentally expanded or logged

2. Public exposure
   - confirm only `80/443` are public
   - confirm `/` remains `404`
   - confirm Telegram webhook endpoints are the only intended public app surface

3. SSH and host access
   - confirm firewall posture remains least-privilege
   - confirm no temporary rescue-user patterns remain in bootstrap
   - review operator access assumptions

4. Reverse proxy and TLS
   - verify nginx config remains minimal
   - verify cert persistence and renewal behavior
   - confirm trusted-proxy configuration is appropriate for the current topology

5. OpenClaw configuration
   - verify allowlist behavior for Telegram owner access
   - verify model/provider defaults
   - verify agent bindings cannot silently collapse to single-agent behavior again

6. Repo-level audit
   - inspect shell scripts for unsafe expansion and quoting bugs
   - inspect bootstrap steps for accidental secret leakage
   - inspect generated config paths for privilege or ownership mistakes
   - inspect docs for stale or dangerous operator guidance

### Security hardening backlog

1. Add a documented security review checklist for each release.
2. Consider a safer recovery path than ad hoc console-password workarounds.
3. Tighten SSH/root/sudo posture after current operational pressure drops:
   - disable direct root SSH
   - replace blanket `NOPASSWD:ALL` with a smaller admin surface if practical
4. Decide whether reverse-proxy trusted-proxy settings should be made explicit.
5. Add a guardrail against regressions that silently reintroduce public UI exposure.

## Phase 6: documentation maturity

### Goal

Keep the docs aligned with reality so future operations do not depend on memory.

### Tasks

1. Keep these docs current:
   - `docs/quickstart.md`
   - `docs/architecture.md`
   - `docs/openclaw-nginx-letsencrypt-plan.md`

2. Add a dedicated operations runbook if the system keeps growing:
   - rebuilds
   - recovery
   - Telegram maintenance
   - model/provider maintenance
   - release workflow

3. Add an agent catalog document if more specialists are introduced.

## Suggested execution order

1. Rebuild and verify the current identity-metadata change.
2. Tag the next release if that rebuild passes.
3. Execute the first three priority security fixes.
4. Evaluate and choose a better memory-system direction.
5. Clean up agent architecture so routing and identity have a clearer source of truth.
6. Only then consider adding a treasurer bot.
7. Tackle the deferred SSH/root/sudo hardening work near the end of this cycle.

## Definition of done for the next checkpoint

The next checkpoint should be considered complete when:

1. A fresh rebuild shows the friendly bot names in the dashboard.
2. `bob`, `jennifer`, and `stacks` all reply successfully after rebuild.
3. Docs reflect the current state without known major staleness.
4. A first-pass security audit has been completed and written down.

## Dashboard auth follow-up

- Root-cause the Control UI `device signature invalid` behavior seen on OpenClaw builds newer than `v2026.3.2`.
- Test a newer OpenClaw version only as an explicit pinned upgrade, not by drifting back to `main`.
- Before unpinning from `v2026.3.2`, verify:
  - dashboard token flow
  - Control UI device pairing/reconnect
  - all five bot runtime containers
  - Telegram ingress and reply behavior
