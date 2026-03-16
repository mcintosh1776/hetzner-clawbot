# Operator quickstart

This is the shortest practical path for operating the current platform.

Use this when you do not want to read the full handbook first.

## 1. Know the current boundaries

- bots can read allowed memory scopes
- bots can write observation candidates
- bots cannot silently promote canonical memory
- bots cannot deploy or publish without approval
- Bob can route work, but not approve risky actions

## 2. Know the three most important memory commands

```text
clawbot-observation-review list tenant_0
clawbot-memory-reindex tenant_0
clawbot-memory-reindex tenant_0 --embed
```

## 3. Know the transcript import path

```text
clawbot-import-podcast-transcripts fetch-feed tenant_0 --limit 10
clawbot-memory-reindex tenant_0 --embed
clawbot-qmd-tenant query tenant_0 steve "Cypherpunk Manifesto"
```

## 4. Know the shared template path

```text
clawbot-template-library list
clawbot-template-library show youtube-specialist
clawbot-template-library copy tenant_0 youtube-specialist steve-youtube
```

## 5. Know the rebuild gate

Do not test the rebuilt node until bootstrap completes.

Use:

```text
tail -n 40 /var/log/cloud-init-output.log
```

Wait for:

- `openclaw node bootstrap complete.`
- or the final `Cloud-init ... finished`

## 6. If memory answers look stale

Run:

```text
clawbot-memory-reindex tenant_0 --embed
```

Then test one known-good query.

## 7. If transcript imports look wrong

Do not bulk import more.

Instead:

1. inspect one imported transcript chunk
2. inspect frontmatter
3. fix format before growing the corpus

## 8. If a bot needs to hand work to another bot

Do not rely on casual chat.

Use:

- [bot-handoff-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/bot-handoff-contract.md)
- [work-queue-format.md](/home/mcintosh/repos/hetzner-clawbot/docs/work-queue-format.md)

## 9. If you only read three docs

Read these:

- [operator-handbook.md](/home/mcintosh/repos/hetzner-clawbot/docs/operator-handbook.md)
- [bot-handoff-contract.md](/home/mcintosh/repos/hetzner-clawbot/docs/bot-handoff-contract.md)
- [shared-template-library.md](/home/mcintosh/repos/hetzner-clawbot/docs/shared-template-library.md)
