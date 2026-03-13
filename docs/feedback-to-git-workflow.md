# Feedback-to-Git Workflow

## Purpose

Define how agents can propose improvements to their own identity, behavior, and
publishing guidance without being allowed to mutate the private source of truth
directly.

## Goal

Keep the runtime harness generic while allowing agent quality to improve through:

- operator feedback
- agent self-critique
- Git-reviewed updates to the private `clawbot-agents` repository

## Non-goals

- direct autonomous writes to canonical files from production runtimes
- silent prompt drift
- unreviewed edits to `main`

## Design principles

- Canonical files remain human-controlled.
- Agents may propose, but not apply, changes.
- Every accepted change is reviewable, diffable, and revertible.
- Production only consumes pinned tags or commits.

## Source of truth

Canonical agent behavior remains in the private repo:

- `clawbot-agents`

Typical files:

- shared:
  - `FOUNDATION.md`
  - `VOICE.md`
  - `CHAIN_OF_COMMAND.md`
  - `agents/PUBLISHING.md`
  - `agents/SECRET_HANDLING.md`
  - `agents/SOCIAL_POSTING.md`
- per-agent:
  - `IDENTITY.md`
  - `SOUL.md`
  - `AGENT.md`
  - `MEMORY.md`
  - `RELATIONSHIPS.md`
  - `FEEDBACK.md`
  - `SKILLS/`

## Proposal model

Agents do not edit canonical files directly.

Instead, they generate one of:

- a proposed patch
- a proposed replacement file body
- a structured feedback entry

These proposals are written to a non-canonical review area.

## Recommended review areas

Choose one of these models.

### Model A: proposals directory in the private repo

Example:

- `proposals/podcast_media/2026-03-13-social-tone.md`
- `proposals/research/2026-03-13-editorial-guidance.md`

Pros:

- very simple
- easy to review in Git

Cons:

- requires a proposal import step

### Model B: generated patch files

Example:

- `proposals/podcast_media/2026-03-13-feedback.patch`

Pros:

- precise
- close to final Git diff

Cons:

- harder for agents to produce correctly

### Model C: branch or PR workflow

Agents or operator tooling create a branch in the private repo and open a PR.

Pros:

- cleanest long-term developer workflow

Cons:

- more moving parts
- should not be the first step

## Recommended first implementation

Start with Model A.

Use:

- `proposals/<agent-id>/<timestamp>-<topic>.md`

Recommended home:

- inside the private `clawbot-agents` repo

Each proposal file should contain:

- why the change is needed
- observed draft behavior
- proposed change
- exact file targets
- suggested diff or replacement text

## Proposal file format

Suggested structure:

```md
# Proposal

## Agent
podcast_media

## Reason
Stacks used generic marketing language and weak Bitcoin framing in a Nostr draft.

## Observed behavior
- said "crypto" where "Bitcoin" was intended
- overused vague promo language

## Proposed change
Tighten `agents/podcast_media/AGENT.md` and `agents/podcast_media/FEEDBACK.md` to prefer Bitcoin-native language and stronger media-operator tone.

## Target files
- agents/podcast_media/AGENT.md
- agents/podcast_media/FEEDBACK.md

## Suggested content
...
```

## Operator review flow

1. Agent proposes a change.
2. Proposal lands in the review area, not the canonical source path.
3. Operator reviews the proposed edit.
4. Operator accepts, edits, or rejects it.
5. Accepted change is applied to canonical files in `clawbot-agents`.
6. Renderer is run.
7. New private repo tag is created.
8. Public infra repo is bumped to the new tag.
9. Production rebuild consumes the new behavior.

## Helper command

This repo also provides a small helper to generate proposal stubs:

```bash
scripts/new-feedback-proposal.sh <agent-id> <topic-slug>
```

It prints a ready-to-edit proposal markdown document to stdout. Redirect it into
the private repo proposal path, for example:

```bash
scripts/new-feedback-proposal.sh podcast_media social-tone \
  > /path/to/clawbot-agents/proposals/podcast_media/2026-03-13-social-tone.md
```

## Runtime boundary

Production runtimes must remain read-only against the canonical repo.

Allowed:

- generate proposals
- export proposal text
- store proposal drafts in a review queue

Not allowed:

- push directly to canonical `main`
- rewrite canonical files in place
- retag production refs

## Auth and access model

When this is implemented, prefer:

- proposal-only Git access
- separate machine user or deploy identity
- no write access from the same credentials used for production read-only fetch

## Minimal milestone plan

### M1

- document the workflow
- keep proposal creation manual

### M2

- add proposal templates
- define exact proposal folder layout in `clawbot-agents`

### M3

- add a runtime command or tool that emits proposal text instead of raw
  conversational suggestions

### M4

- optional branch/PR automation

## Open questions

- Should proposals live in `clawbot-agents` or a separate review repo?
- Should proposals be per-agent only, or can there be shared proposals?
- What approvals are required before a proposal can be merged?

## Current recommendation

- keep canonical files human-reviewed
- let agents propose changes
- keep production consumption pinned to reviewed tags
- do not allow direct autonomous self-modification
