# Operator handbook

This is the working operator runbook for the current Clawbot platform.

It is written for the human operator, not for the bots.

## Purpose

The operator handbook exists to define:

- what the operator is responsible for
- what the bots are allowed to do without asking
- what requires review or approval
- how to recover when something goes wrong

## Current operator responsibilities

The operator currently owns:

- rebuild/apply decisions
- secret management
- tenant creation
- bot/channel approvals
- canonical-memory review and promotion decisions
- release/tag decisions
- incident response when production behavior drifts

## Current system shape

The current live platform includes:

- tenant-aware state under `/opt/clawbot/tenants/tenant_0/`
- canonical memory
- observation memory
- transcript retrieval for Steve
- read-only memory retrieval for the full current fleet
- observation review/promotion tooling
- shared template library scaffold

## Roles in practice

### Operator

The operator is the final authority for:

- deploys
- publishing
- secrets
- tenant boundaries
- approval of risky changes

### Bob

Bob should increasingly behave as:

- router
- queue owner
- escalation point
- workflow controller

Not as:

- final approver for risky actions
- secret manager

### Specialist bots

Specialist bots should increasingly be treated as:

- bounded workers with explicit scopes
- owners of a task while it is assigned to them
- responsible for producing structured handoffs when passing work on

## Core operator commands

These are the practical commands the operator should know first.

### Memory

```text
clawbot-observation-review list tenant_0
clawbot-observation-review show tenant_0 <observation-id>
clawbot-observation-review reject tenant_0 <observation-id>
clawbot-observation-review promote tenant_0 <observation-id>
clawbot-memory-reindex tenant_0
clawbot-memory-reindex tenant_0 --embed
```

### Transcript retrieval

```text
clawbot-import-podcast-transcripts fetch-feed tenant_0 --limit 10
clawbot-memory-reindex tenant_0 --embed
clawbot-qmd-tenant query tenant_0 steve "Cypherpunk Manifesto"
```

### Template library

```text
clawbot-template-library list
clawbot-template-library show youtube-specialist
clawbot-template-library copy tenant_0 youtube-specialist steve-youtube
```

## Approval matrix

Use this as the default approval boundary until a control board exists.

### Bot may do without asking

- read allowed memory scopes
- write observation candidates
- produce proposals, drafts, and handoff packets
- copy a shared template into a tenant-owned scaffold
- run bounded retrieval against allowed corpora

### Bob may route without asking

- assign or reassign work between bots
- reject incomplete handoffs
- move tasks between queue states
- escalate blocked work to the operator

### Operator approval required

- deploys, rebuilds, or service restarts
- external publishing or outbound sends
- secret creation, rotation, or exposure
- permission broadening
- canonical memory promotion if the content is sensitive or high-impact
- any destructive or hard-to-reverse action

## Decision boundaries

The current safe default is:

- bots may read allowed memory scopes
- bots may write observations
- bots may not silently promote canonical memory
- bots may not publish or deploy without explicit approval
- bots may not broaden permissions on their own

## Daily operator cadence

This should be the default daily rhythm once the system is busy enough to justify it.

### Morning

1. Check whether any services or rebuilds failed overnight.
2. Review pending observations.
3. Review blocked work items and incomplete handoffs.
4. Check whether any transcript or retrieval jobs need reindexing.

### Midday

1. Review active bot work ownership.
2. Approve or reject high-value proposals.
3. Confirm no bot is stalled behind missing operator input.

### End of day

1. Review what moved to `ready_for_approval`.
2. Queue overnight work deliberately.
3. Make sure risky actions are not left half-approved.

## Weekly operator cadence

At least once per week:

1. review canonical memory quality
2. retire or reject low-value observations
3. review transcript/import quality and corpus growth
4. review copied template sprawl and whether any should become shared templates
5. review release/changelog discipline

## Normal operating workflows

### 1. Observation -> canonical memory

1. Bot stores observation candidate.
2. Operator reviews pending observations.
3. Operator rejects or promotes.
4. Operator reindexes memory.

### 2. Transcript ingestion

1. Import a bounded transcript batch.
2. Reindex with embeddings.
3. Test one or two real retrieval queries.
4. Expand only after quality looks acceptable.

### 3. Template-based bot creation

1. List templates.
2. Copy a template into a tenant-owned path.
3. Tune the copied guidance/config.
4. Later wire it into runtime/channels deliberately.

### 4. Multi-bot work handoff

1. Assign one current owner.
2. Require explicit task state.
3. Require a structured handoff packet for ownership changes.
4. Route through Bob.
5. Escalate approval-required states to the operator.

Reference:

- [bot-handoff-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/bot-handoff-contract.md)

## Planned workflow: structured bot handoffs

Multi-bot work should move through explicit handoffs, not casual chat.

Recommended states:

- `todo`
- `in_progress`
- `ready_for_qa`
- `qa_failed`
- `qa_passed`
- `ready_for_approval`
- `done`

Required handoff packet contents:

- task id
- from / to
- status
- summary
- files touched
- verify steps
- known risks
- open questions

This should eventually become:

- a bot work queue
- a handoff contract
- Bob-managed routing between specialist bots

## Recovery / troubleshooting

## Incident categories

Use these categories to decide response speed and who should be involved.

### Category 1: platform down

Examples:

- bootstrap failed
- main runtime unavailable
- Telegram/webhook path broken
- core retrieval path unavailable

Operator action:

- stop feature work
- restore baseline service
- avoid concurrent architecture changes

### Category 2: behavior drift

Examples:

- a bot answers from the wrong memory scope
- transcript retrieval quality drops sharply
- canonical retrieval is stale after promotion

Operator action:

- isolate whether the issue is corpus, index, or routing
- reindex if appropriate
- avoid promoting more memory until root cause is understood

### Category 3: workflow failure

Examples:

- incomplete handoff packets
- QA work not routed back correctly
- Bob queue state drift

Operator action:

- correct the workflow contract first
- avoid adding more bots to a broken workflow

### Bootstrap changes

If `bootstrap-node-runner.sh` changes:

- update the pinned SHA in `live/prod/fsn1/clawbot/terragrunt.hcl`
- do that in the same milestone before rebuild/apply

### Rebuild discipline

Do not validate the node until bootstrap completes.

Use:

```text
tail -n 40 /var/log/cloud-init-output.log
```

Wait for:

- `openclaw node bootstrap complete.`
- or the final `Cloud-init ... finished`

### If retrieval looks stale

Run:

```text
clawbot-memory-reindex tenant_0
clawbot-memory-reindex tenant_0 --embed
```

### If observation promotion happened but answers are stale

1. confirm the canonical file exists
2. confirm the observation status is `accepted`
3. run:

```text
clawbot-memory-reindex tenant_0 --embed
```

### If transcript import quality looks bad

1. stop bulk importing
2. inspect one imported transcript chunk
3. inspect frontmatter before changing retrieval logic
4. only widen the corpus again after one episode looks correct

## Operator checklist before ending a session

Before stepping away, the operator should know:

- whether a rebuild is still in progress
- whether bootstrap is complete
- whether any risky work is waiting on approval
- whether any queue item is blocked only because of missing operator input
- whether local uncommitted docs or code are intentionally being held back

## Immediate gaps

These are still missing and should be treated as active platform gaps:

- operator-facing control board
- structured bot work queue
- explicit QA bot and handoff contract
- tenant creation workflow
- diff/upgrade tooling for copied templates
- fuller incident runbooks

## Near-term documentation set

The operator-facing documentation set should now be treated as:

- [operator-quickstart.md](/home/mcintosh/repos/hetzner-clawbot/docs/operator-quickstart.md)
- [operator-handbook.md](/home/mcintosh/repos/hetzner-clawbot/docs/operator-handbook.md)
- [bot-handoff-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/bot-handoff-contract.md)
- [work-queue-format.md](/home/mcintosh/repos/hetzner-clawbot/docs/work-queue-format.md)
- [rebuild-and-release-runbook.md](/home/mcintosh/repos/hetzner-clawbot/docs/rebuild-and-release-runbook.md)
- [shared-template-library.md](/home/mcintosh/repos/hetzner-clawbot/docs/shared-template-library.md)
- [observation-review-cli.md](/home/mcintosh/repos/hetzner-clawbot/docs/observation-review-cli.md)
- [transcript-regression-harness.md](/home/mcintosh/repos/hetzner-clawbot/docs/transcript-regression-harness.md)
