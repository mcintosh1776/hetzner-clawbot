# Bot Runtime and Queue Contract

## Purpose

This document records the runtime, queue, and routing behavior that the Clawbot stack depends on. The goal is to make the workflow deterministic and to avoid re-debugging the same integration failures.

## Private runtime interface

Private runtimes are not generic chat endpoints.

Current live pattern:
- status endpoint: `/v1/runtime/status`
- Telegram ingress endpoint: `/v1/inbound/telegram`

Do not assume `/v1/chat/completions` exists on a private runtime. For operator-driven runtime testing, use the same inbound route shape the Telegram relay uses.

## Private runtime auth

Private runtimes expect:
- `Authorization: Bearer <OPENCLAW_PRIVATE_RUNTIME_API_TOKEN>`

The token is runtime-local configuration. It must not be committed to git or inferred from tenant content paths.

## Telegram inbound event shape

Private runtimes expect inbound Telegram-style payloads shaped like:

```json
{
  "event": {
    "chat": { "id": 1619231777 },
    "sender": { "id": 1619231777, "username": "mcintosh" },
    "messageId": 999001,
    "text": "move task example-task to in_progress"
  }
}
```

Relevant fields:
- `event.chat.id`
- `event.sender.id`
- `event.sender.username`
- `event.messageId`
- `event.text`

Operator-only paths depend on the sender identity matching the configured operator id.

## Runtime action response shape

Private runtimes return action instructions, not direct Telegram delivery:

```json
{
  "ok": true,
  "actions": [
    {
      "type": "telegram.sendMessage",
      "target": {
        "chatId": 1619231777,
        "replyToMessageId": 999001
      },
      "message": {
        "text": "Task example-task moved to in_progress."
      }
    }
  ]
}
```

The webhook relay is responsible for executing those actions.

## Queue workflow contract

Queue state transitions must be explicit platform primitives.

Supported primitives:
- `show task <task-id>`
- `move task <task-id> to <state>`
- `start task <task-id>`
- `complete task <task-id>`
- `hand off task <task-id> to <owner> status <state>: <summary>`

Current queue states in active use:
- `todo`
- `in_progress`
- `blocked`
- `ready_for_approval`
- `done`

## Queue mutation rule

Bots must not claim progress, completion, blocking, or handoff unless the queue mutation succeeded.

This is a standing behavior rule, not a per-task reminder.

## Engineering honesty rule

If a bot cannot access or verify a file, function, repo, endpoint, output, or other artifact, it must say it is blocked.

Bots must not invent:
- file paths
- function names
- patch points
- endpoints
- outputs
- system state

Unverified code or artifact references are a hard failure.

## Queue API contract

The memory/queue layer exposes explicit task movement:
- `POST /v1/queue/tasks/{task_id}/move`

Runtime queue features should call the queue API rather than attempting filesystem mutation directly.

## Routing precedence

Routing inside private runtimes must be deterministic.

Required precedence:
1. operational commands
2. queue commands
3. explicit workflow actions
4. specialist capability routes
5. open-ended generation

Do not let creative/proposal/profile classifiers capture queue or operator-control prompts.

## Capability boundaries

Capabilities must be explicitly scoped per agent.

Examples:
- proposal-generation flows only for agents that are meant to open reviewed proposals
- Nostr draft/profile flows only for agents that are meant to produce publishing drafts
- queue mutation available to task-driven specialists
- PR/archive operations only through the intended workflow owner/tooling

Avoid broad phrase-based routing without an agent capability check.

## Relay behavior

The Telegram relay must:
- record dedupe only after a successful forward
- log enough context to debug failures
- redact secrets
- avoid leaking token-bearing URLs through transport-library logging
- use `allow_sending_without_reply=true` on outbound replies

If the first forward fails, retries must not be poisoned as duplicates.

## Debugging guidance

If a bot receives messages but does not move queue state:
- verify the queue task path and state on disk
- verify the runtime is using the queue move primitive
- verify the prompt hit the queue command branch rather than a proposal/profile classifier

If a bot cites a file, function, or patch point:
- verify that the referenced code actually exists in the accessible repo/workspace
- if the runtime cannot access the relevant repo, treat invented references as a behavior failure and the missing mount as a capability failure

If a direct runtime probe returns `Not Found`:
- check the actual live route set in the runtime app
- do not assume a generic chat endpoint

If a queue move succeeds but the bot still errors:
- inspect the acknowledgement/rendering path
- verify the reply uses canonical task metadata from the queue result

If Telegram appears silent:
- check relay dedupe behavior
- check webhook logs
- check that outbound Telegram transport logs are not hiding or leaking the real failure

## Practical test pattern

When testing a private runtime directly, prefer:
1. use the actual inbound Telegram route
2. use the runtime bearer token
3. send an operator-shaped event payload
4. verify both:
   - returned action payload
   - queue state on disk

Do not treat a chat reply alone as proof that queue state changed.

## Design rule

Queue/workflow primitives and capability guardrails are foundational infrastructure. They should be treated as platform contracts, not prompt tricks.

## Current Steve status

Steve implementation ownership is currently paused pending runtime enforcement redesign.

Reason:
- queue/runtime/workspace plumbing is working
- but freeform coding replies are still able to fabricate unsupported implementation claims

Required before resuming Steve implementation work:
- evidence-gated coding modes
- validated file claims
- later, validated symbol and edit claims
