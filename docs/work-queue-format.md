# Work queue format

This defines the first file-backed queue format for multi-bot work.

The goal is to make task routing explicit before any control board exists.

## Why file-backed first

The first queue should be:

- easy to inspect
- easy to move between states
- easy to debug on disk
- easy for Bob to reason about

That means files first, not a database first.

## Recommended layout

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
  cancelled/
```

Each task is one markdown file with YAML frontmatter.

## Required fields

```yaml
task_id: website-homepage-v1
tenant_id: tenant_0
title: Homepage first pass
requested_by: operator
current_owner: steve
status: in_progress
priority: medium
created_at: 2026-03-16T22:55:00Z
updated_at: 2026-03-16T22:55:00Z
category: implementation
requires_operator_approval: false
```

## Recommended body sections

```md
## Objective

Build the first homepage implementation.

## Constraints

- no deploy
- no external publishing

## Artifacts

- web/index.html
- web/styles.css

## Verify

- load homepage
- test mobile nav

## Notes

- CTA copy still placeholder
```

## Naming convention

Suggested filename:

```text
<task_id>.md
```

Do not encode state in the filename.
The directory already represents state.

## Ownership change rule

When a task changes owner:

1. update frontmatter:
   - `current_owner`
   - `status`
   - `updated_at`
2. add a handoff section in the body or linked packet
3. move the file to the directory matching the new state

## Minimal handoff section

```md
## Latest handoff

- from: steve
- to: qa
- at: 2026-03-16T23:10:00Z
- summary: first pass complete, ready for QA
- files touched:
  - web/index.html
  - web/styles.css
- verify:
  - test mobile layout
  - test nav open/close
```

## Bob's queue rules

Bob should:

- reject tasks missing required fields
- reject state/owner mismatches
- refuse to move a task to `ready_for_qa` without verify steps
- refuse to move a task to `ready_for_approval` without a completed QA result if QA was required

## First-version limits

The first queue format does not need:

- concurrency control
- partial locking
- fancy history storage
- DB-backed search

It does need:

- explicit state
- explicit owner
- explicit handoff
- explicit approval boundary
