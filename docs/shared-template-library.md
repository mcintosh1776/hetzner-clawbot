# Shared template/config library

This is the first usable scaffold for the shared tenant-copyable bot template library.

It is intentionally simple:

- shared templates are centrally defined
- tenants copy a template into a tenant-owned directory
- the copied bundle is edited by the tenant afterward
- the copy is not live runtime wiring by itself

## CLI

Bootstrap installs:

- `/usr/local/bin/clawbot-template-library`

Usage:

```text
clawbot-template-library list
clawbot-template-library show <template-id>
clawbot-template-library copy <tenant-id> <template-id> <bot-id> [--display-name <name>] [--output-dir <path>]
```

## Current shared templates

- `podcast-media`
- `research`
- `engineering`
- `business`
- `qa`
- `security`
- `youtube-specialist`
- `social-media-specialist`
- `mail-inbox-specialist`

The first four reuse the current specialist guidance already present on the node.
`qa` is the first review-focused shared template and uses an embedded guidance scaffold.
`security` is the first security-review shared template and is intentionally review-only.
The last three are starter templates for future tenant expansion.

## Copy target

By default, a copy lands at:

```text
/opt/clawbot/tenants/<tenant_id>/config/template-copies/<bot_id>/
```

Files written:

- `bot.json`
- `guidance.md`
- `README.md`

## What the copied bundle is for

The copied bundle is a tenant-owned scaffold.

It is meant to be:

- renamed
- tuned
- reviewed
- later wired into live runtime/channel config

It is not meant to:

- mutate the shared template in place
- create shared live bot instances
- bypass review for runtime wiring

## Safe tenant edits

Tenants may safely tune:

- display name
- channel list
- role description
- guidance text
- tenant-specific operating rules

## Deliberate limitations

This first version does not yet:

- wire the copied bundle into runtime automatically
- expose a web control board
- maintain version sync between shared templates and tenant copies
- provide diff/upgrade tooling for copied templates

That is deliberate. The first requirement is a clean copy boundary.
