# PR Automation Contract for `clawbot-agents`

## Purpose

Define a low-friction, reviewable write-back path for agents to propose updates
to the private `clawbot-agents` repository without granting them direct write
access to canonical `main`.

## Goal

Allow agents to:

- prepare changes to canonical private agent files
- commit those changes on isolated branches
- open GitHub pull requests automatically

while preserving:

- human review before merge
- pinned-tag production deployments
- clear audit trails

## Non-goals

- direct pushes to `main`
- automatic merges to canonical production content
- automatic production retagging or deployment

## Access model

Use three separate trust roles.

### 1. Deploy reader

Purpose:
- production bootstrap fetches `clawbot-agents`

Permissions:
- read-only

Credential type:
- current deploy key is sufficient

### 2. Proposal writer

Purpose:
- create branches
- push commits
- open PRs

Permissions:
- write to non-protected branches only
- open pull requests
- no merge permission
- no tag creation for release refs

Preferred credential type:
- GitHub App

Acceptable fallback:
- dedicated machine user with a fine-scoped token

### 3. Human reviewer

Purpose:
- review
- request changes
- merge
- create release tag used by production

Permissions:
- normal maintainer/admin path

## Recommended GitHub model

Preferred:
- one GitHub App dedicated to `clawbot-agents` proposal automation

Why:
- revocable
- scoped to one repo
- no shared human PAT
- easier long-term hygiene

Fallback:
- one dedicated machine user
- repo-scoped token
- branch/PR permissions only

Do not use:
- the read-only deploy key
- a maintainer's personal token

## Branch model

Agents should never work directly on `main`.

Branch naming:

- `agent/<agent-id>/<topic-slug>`

Examples:

- `agent/podcast_media/social-tone`
- `agent/research/editorial-guidance`
- `agent/orchestrator/escalation-language`

## Allowed file scope

Agents may propose changes only inside:

- shared policy files in the private repo
- per-agent content files
- renderer and rendered exports if needed

Allowed examples:

- `FOUNDATION.md`
- `VOICE.md`
- `CHAIN_OF_COMMAND.md`
- `agents/PUBLISHING.md`
- `agents/SECRET_HANDLING.md`
- `agents/SOCIAL_POSTING.md`
- `agents/<agent-id>/**`
- `scripts/render-agent-config.sh`
- `exports/agent-config/**`

Disallowed:

- repo settings
- release tags
- branch protection
- secrets
- deploy credentials

## Change model

Agents may modify canonical files on their own branch.

That is better than a “proposal-only markdown file forever” model because:

- it removes manual copy/paste
- it produces the actual diff for review
- it fits normal GitHub review better

The old proposal-template workflow can still exist as a fallback or first draft,
but the main path should be:

1. create branch
2. edit canonical files
3. run renderer if needed
4. commit
5. open PR

## Commit rules

Suggested commit format:

- `agent(<agent-id>): <summary>`

Examples:

- `agent(podcast_media): tighten bitcoin-first posting tone`
- `agent(research): improve editorial caution language`

## Pull request rules

Suggested PR title:

- `<agent-id>: <summary>`

Suggested PR body sections:

- reason
- observed behavior
- files changed
- expected outcome
- risks

## Runtime-to-PR workflow

### Step 1

Agent identifies a concrete improvement.

### Step 2

Runtime prepares a candidate patch or file updates.

### Step 3

A proposal-writer credential creates a new branch.

### Step 4

Runtime/tooling writes the updated files into that branch workspace.

### Step 5

Renderer is executed if the change affects exported prompt files.

### Step 6

Changes are committed and pushed.

### Step 7

A GitHub PR is opened automatically.

### Step 8

Human reviews and merges if acceptable.

### Step 9

Human creates a new private repo tag.

### Step 10

Public infra repo is bumped to the new tag and rebuilt.

## Safety rules

- No automatic merge.
- No automatic tag update.
- No automatic production rollout.
- No credential reuse between deploy-read and proposal-write paths.
- No ability for production runtimes to modify repo secrets or settings.

## Minimal first implementation

### M1

- document the PR contract
- choose credential type

### M2

- add branch naming and PR templates to `clawbot-agents`

### M3

- create a small helper that:
  - creates a branch
  - writes files
  - commits
  - pushes
  - opens a PR

### M4

- expose that helper as a runtime capability for selected bots

## Recommendation

Implement this in phases:

1. GitHub App or machine-user decision
2. branch + PR helper
3. limited rollout to one bot first, likely `podcast_media`
4. human-reviewed merges only

This gets you the low-friction workflow you want without giving agents direct
control over canonical production state.

## Initial helper

This repo provides an operator-side helper for the first PR workflow slice:

```bash
scripts/clawbot-agents-pr.sh <agent-id> <topic-slug> <repo-path> [summary]
```

It:

1. reads the GitHub App credentials from the configured root-owned files
2. creates an installation token
3. creates a proposal branch
4. commits the current changes in the target `clawbot-agents` working tree
5. pushes the branch
6. opens a pull request

It is intentionally operator-run first, not runtime-invoked.
