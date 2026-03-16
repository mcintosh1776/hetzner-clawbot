# Work queue CLI

Bootstrap installs:

- `/usr/local/bin/clawbot-work-queue`

This is the first file-backed queue tool for tenant work routing.

It is intentionally small.

## Commands

```text
clawbot-work-queue list <tenant-id> [--state <state>] [--owner <bot-id>]
clawbot-work-queue show <tenant-id> <task-id>
clawbot-work-queue create <tenant-id> <task-id> --title <title> --owner <bot-id> [--requested-by <actor>] [--priority <level>] [--category <kind>] [--state <state>]
clawbot-work-queue move <tenant-id> <task-id> <state> [--owner <bot-id>]
clawbot-work-queue handoff <tenant-id> <task-id> --to <bot-id> --status <state> --summary <text> [--from <bot-id>]
```

## Queue root

```text
/opt/clawbot/tenants/<tenant_id>/work-queue/
```

The CLI creates the queue-state directories automatically.

## Current states

- `todo`
- `in_progress`
- `blocked`
- `ready_for_qa`
- `qa_failed`
- `qa_passed`
- `ready_for_approval`
- `done`
- `cancelled`

## First-version rules

- one task file per work item
- state is represented by the directory
- ownership is explicit in frontmatter
- handoffs append a `Latest handoff` section to the task body

## Example

```text
clawbot-work-queue create tenant_0 website-homepage-v1 --title "Homepage first pass" --owner steve --category implementation --state in_progress
clawbot-work-queue handoff tenant_0 website-homepage-v1 --to qa --status ready_for_qa --summary "First pass complete, ready for QA."
clawbot-work-queue show tenant_0 website-homepage-v1
```
