# Rebuild and release runbook

This defines the practical release path for the current platform.

## Milestone discipline

When a milestone is ready:

1. update `CHANGELOG.md`
2. commit the milestone
3. tag the release
4. push `main`
5. push the tag

## Bootstrap discipline

If `modules/clawbot_server/bootstrap-node-runner.sh` changes:

1. update the pinned SHA in:
   - `live/prod/fsn1/clawbot/terragrunt.hcl`
2. do this in the same milestone
3. do not rebuild before that pin is correct

## Rebuild procedure

From:

```text
live/prod/fsn1/clawbot
```

Use:

```text
terragrunt apply -auto-approve
```

This currently replaces the node because `user_data` changes force replacement.

## After apply

Do not test services immediately.

Wait for bootstrap:

```text
tail -n 40 /var/log/cloud-init-output.log
```

Completion markers:

- `openclaw node bootstrap complete.`
- final `Cloud-init ... finished`

## Post-bootstrap validation rule

Do the smallest validation that proves the milestone.

Examples:

- for a new CLI: run only that CLI
- for memory promotion: list/show/promote one observation
- for transcript retrieval: import a bounded batch and run one known-good query

Do not widen validation casually.

## If bootstrap fails

First classify the failure:

1. stale runner checksum fetch
2. dependency/runtime install failure
3. later service/bootstrap logic failure

Do not mix debugging with feature work until the baseline node is healthy again.

## Release caution

Do not bundle unrelated local docs or experiments into a milestone release unless that is deliberate.

Keep:

- milestone code
- milestone docs
- pinned SHA updates

together.
