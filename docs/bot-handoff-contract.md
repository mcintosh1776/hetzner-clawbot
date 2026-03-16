# Bot handoff contract

This defines the minimum contract for one bot handing work to another.

The goal is simple:

- no hidden state
- no vague "done" messages
- no QA based on guesswork

## Why this exists

Specialist bots will eventually work in sequence.

Example:

- Steve implements
- QA verifies
- Bob routes and tracks
- operator approves high-risk steps

Without a handoff contract, work quality will degrade quickly.

## Required state machine

Every work item should have one of these states:

- `todo`
- `in_progress`
- `blocked`
- `ready_for_qa`
- `qa_failed`
- `qa_passed`
- `ready_for_approval`
- `done`
- `cancelled`

## Required ownership fields

Every work item should include:

- `task_id`
- `tenant_id`
- `current_owner`
- `requested_by`
- `status`
- `priority`
- `created_at`
- `updated_at`

## Required handoff packet

When a bot hands work off, it must include:

- `task_id`
- `from_bot`
- `to_bot`
- `status`
- `summary`
- `objective`
- `artifacts`
- `files_touched`
- `verify_steps`
- `known_risks`
- `open_questions`
- `handoff_at`

## Minimal packet example

```yaml
task_id: website-homepage-v1
tenant_id: tenant_0
from_bot: steve
to_bot: qa
status: ready_for_qa
summary: First-pass homepage implementation is complete.
objective: Verify layout, mobile behavior, and basic interaction flow.
artifacts:
  - web/index.html
  - web/styles.css
  - web/app.js
files_touched:
  - web/index.html
  - web/styles.css
  - web/app.js
verify_steps:
  - Open the homepage on desktop.
  - Check mobile layout at 390px width.
  - Trigger nav open/close.
  - Trigger form validation.
known_risks:
  - No Safari pass yet.
  - Placeholder marketing copy remains in section 3.
open_questions:
  - Should the hero CTA go to signup or podcast page?
handoff_at: 2026-03-16T22:40:00Z
```

## QA response contract

QA should not respond with casual comments.

QA must return:

- `task_id`
- `from_bot`
- `to_bot`
- `status`
- `summary`
- `findings`
- `severity`
- `repro_steps`
- `recommended_next_owner`
- `updated_at`

## QA response example

```yaml
task_id: website-homepage-v1
from_bot: qa
to_bot: steve
status: qa_failed
summary: Two issues found in mobile layout and validation styling.
findings:
  - Mobile menu overlaps hero copy at 390px width.
  - Form error text contrast is too low.
severity:
  - medium
  - low
repro_steps:
  - Set viewport width to 390px and open menu.
  - Submit the form empty and inspect error state.
recommended_next_owner: steve
updated_at: 2026-03-16T23:05:00Z
```

## Bob's routing responsibilities

Bob should act as workflow controller, not as a vague middleman.

Bob must:

- validate required handoff fields exist
- reject incomplete handoffs
- change ownership explicitly
- advance or return tasks based on state
- escalate approval-required states to the operator

Bob should not:

- silently rewrite technical findings
- approve risky work on behalf of the operator
- skip QA for implementation work unless the workflow says so

## Approval boundaries

The following states should typically require operator review:

- `ready_for_approval`
- any deploy or publish step
- any secret or permission broadening step
- any production-risking infrastructure step

## Storage recommendation

The first version should use file-backed work items.

Suggested layout:

```text
/opt/clawbot/tenants/<tenant_id>/work-queue/
  todo/
  in_progress/
  blocked/
  ready_for_qa/
  qa_failed/
  qa_passed/
  ready_for_approval/
  done/
```

This keeps the system auditable and simple before building a control board.

## First-version rule

The first version should optimize for:

- explicitness
- reversibility
- easy inspection by the operator

Not for:

- elegance
- abstraction
- automation depth

That comes later.
