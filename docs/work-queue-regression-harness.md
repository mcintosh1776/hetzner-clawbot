# Work queue regression harness

This document describes the first executable regression harness for the live `tenant_0` work queue.

Script:
- [scripts/test-work-queue.sh](/home/mcintosh/repos/hetzner-clawbot/scripts/test-work-queue.sh)

## Purpose

The harness exists to catch regressions in:

- queue task creation
- owner-filtered listing
- state transitions
- handoff persistence
- explicit owner reassignment

It is a live-node harness, not a unit test suite.

## What it checks

1. `create`
- creates a task in `in_progress`
- verifies the file path lands in the expected state directory

2. `list --owner steve`
- verifies owner filtering still returns the created task

3. `handoff`
- hands the task from `steve` to `qa`
- moves the task to `ready_for_qa`

4. `show`
- verifies:
  - state is `ready_for_qa`
  - `current_owner` is `qa`
  - the task body contains a `Latest handoff` section

5. `move`
- explicitly moves the task to `qa_failed`
- reassigns ownership to `steve`

## Usage

Run from the repo root:

```bash
scripts/test-work-queue.sh
```

Optional overrides:

```bash
HOST=91.107.207.3 TENANT_ID=tenant_0 TASK_ID=queue-harness-demo scripts/test-work-queue.sh
```

## When to run it

Run this harness after changes to:

- [scripts/work-queue.mjs](/home/mcintosh/repos/hetzner-clawbot/scripts/work-queue.mjs)
- [modules/clawbot_server/bootstrap-node-runner.sh](/home/mcintosh/repos/hetzner-clawbot/modules/clawbot_server/bootstrap-node-runner.sh)
- queue state handling
- handoff persistence logic

## Current limitations

This first harness does not yet prove:

- Bob-mediated queue validation
- multi-task concurrency behavior
- automatic QA routing
- operator approval transitions

It only proves that the file-backed queue substrate is behaving correctly on the live node.
