# Work output CLI

Tenant-local working artifacts for human consumption should live under:

- `/opt/clawbot/tenants/<tenant-id>/outputs/bots/<bot-id>/`

This is the default home for:

- episode packages
- show notes drafts
- social drafts
- promo copy
- other one-off deliverables

It is not the default home for:

- reusable `SKILLS/`
- long-term guidance
- repo/process/config changes

## CLI

Installed on the host as:

- `clawbot-work-output`

Commands:

```bash
clawbot-work-output list <tenant-id> <bot-id>
clawbot-work-output show <tenant-id> <bot-id> <output-id>
clawbot-work-output write <tenant-id> <bot-id> <output-id> --title "<title>" --body-base64 "<base64>"
```

## Runtime-facing commands

Bots with memory-service access can use:

```text
list outputs
show output <output-id>
save output <output-id>: <markdown body>
save output <output-id> title <title>: <markdown body>
```

## Operator guidance

- Prefer chat output when the artifact is short and immediately consumable.
- Prefer saved outputs when the artifact is longer, iterative, or should be revisited later.
- Do not default to repo proposals for normal deliverables.
- Use proposals only when the operator explicitly wants repo/config/process changes.
