# Runtime Service Contract

## Purpose

This document defines the internal service contract for isolated bot runtimes.

It is the concrete output for `M2` in [runtime-isolation-plan.md](/home/mcintosh/repos/hetzner-clawbot/docs/runtime-isolation-plan.md).

Goal:

- keep the current Telegram UX
- move secret-bearing bots behind private runtime boundaries
- make ingress-to-runtime and runtime-to-runtime communication explicit

This contract is intentionally simple. It is designed to be buildable without a
new message bus, database, or orchestration system.

## Scope

This contract covers:

- public ingress to private bot runtime
- private runtime response back to ingress
- runtime-to-runtime delegation
- service authentication between internal components

This contract does not cover:

- public internet API design
- long-term async queue semantics
- treasury approval policy details
- Nostr-specific tool semantics

## Design choices

### Choice 1: HTTP first

Initial implementation should use private HTTP on a host-internal or
private-network interface.

Reason:

- easiest to implement and observe
- easiest to lock down with firewall rules
- easiest to debug with curl and structured logs

### Choice 2: ingress owns Telegram transport

The public ingress layer should:

- receive Telegram webhooks
- validate Telegram secret headers
- know the Telegram bot token for each public bot
- perform outbound Telegram sends

Private runtimes should:

- receive normalized inbound events
- decide what to do
- return structured actions

Why:

- keeps Telegram transport logic in one place
- avoids duplicating Telegram send code in every isolated runtime
- allows high-value runtimes to avoid holding Telegram bot tokens if desired

### Choice 3: structured action responses

Private runtimes should not send arbitrary shell or transport commands back to
ingress.

They should return structured action objects.

Reason:

- easier to validate
- easier to audit
- easier to extend

## Components

### 1. Public ingress

Responsibilities:

- public TLS termination
- Telegram webhook path routing
- transport validation
- normalized event construction
- runtime authentication
- action dispatch back to Telegram

### 2. Private bot runtime

Responsibilities:

- own prompt/config/tool/runtime state
- own high-value secrets
- interpret inbound requests
- return structured actions

Examples:

- `stacks-runtime`
- `treasurer-runtime`

### 3. Optional orchestrator runtime

This may remain the current shared OpenClaw runtime for a while.

Responsibilities:

- front-door coordination
- low-risk general workflows
- delegation to isolated runtimes when needed

## Network model

### Initial target

- ingress can reach private runtimes
- private runtimes can reach ingress only if required for callbacks
- private runtimes can reach each other only if explicitly needed

Default rule:

- deny lateral runtime-to-runtime access unless there is a documented call path

## Authentication model

### Transport security

Use a private network or loopback-only binding where possible.

### Request authentication

Each private runtime should require:

- internal bearer token or HMAC token in a header

Recommended header:

- `Authorization: Bearer <internal-service-token>`

Alternative:

- `X-OpenClaw-Service-Token: <token>`

### Per-service token strategy

Minimum:

- one token per private runtime

Better:

- one token per caller-to-callee relationship

Initial recommendation:

- keep it simple with one token per callee runtime

Examples:

- `STACKS_INTERNAL_API_TOKEN`
- `TREASURER_INTERNAL_API_TOKEN`

Those tokens should live in the same root-owned secret model as other
high-value secrets.

## Versioning

All service requests and responses must include a contract version.

Initial version:

- `contractVersion: 1`

If the contract changes incompatibly:

- bump the version
- keep old version support only if migration actually requires it

## Ingress to runtime request

### Endpoint

- `POST /v1/inbound/telegram`

### Request headers

- `Authorization: Bearer <internal-service-token>`
- `Content-Type: application/json`
- `X-OpenClaw-Request-Id: <uuid>`
- `X-OpenClaw-Bot-Id: <public bot name>`
- `X-OpenClaw-Agent-Id: <internal agent id>`

### Request body

```json
{
  "contractVersion": 1,
  "requestId": "7d6b71f0-4f0c-4457-a61f-f8b523ff6f24",
  "receivedAt": "2026-03-07T18:55:00Z",
  "source": {
    "channel": "telegram",
    "botId": "stacks",
    "accountId": "podcast_media",
    "delivery": "webhook"
  },
  "session": {
    "scope": "per-account-channel-peer",
    "sessionKey": "telegram:podcast_media:1619231777",
    "chatId": "1619231777",
    "peerId": "1619231777",
    "isGroup": false
  },
  "sender": {
    "telegramUserId": "1619231777",
    "username": "mcintosh1775",
    "displayName": "McIntosh",
    "isAuthorized": true
  },
  "message": {
    "messageId": "4123",
    "text": "publish tonight's episode notes to Nostr",
    "rawUpdate": {}
  },
  "context": {
    "publicHostname": "agents.satoshis-plebs.com",
    "environment": "prod",
    "region": "fsn1"
  }
}
```

### Required fields

- `contractVersion`
- `requestId`
- `source.channel`
- `source.botId`
- `source.accountId`
- `session.sessionKey`
- `sender.telegramUserId`
- `message.rawUpdate`

### Why include `rawUpdate`

- preserves forensic/debug value
- allows runtime-specific parsing later
- avoids losing Telegram features too early

The normalized fields still exist so runtimes do not need to unpack the raw
update in common cases.

## Runtime response

### Endpoint response model

The runtime should return HTTP `200` for a validly processed request, even when
the business result is “no reply”.

Use HTTP `4xx` or `5xx` only for contract/auth/runtime failures.

### Response body

```json
{
  "contractVersion": 1,
  "requestId": "7d6b71f0-4f0c-4457-a61f-f8b523ff6f24",
  "status": "ok",
  "actions": [
    {
      "type": "telegram.sendMessage",
      "target": {
        "chatId": "1619231777",
        "replyToMessageId": "4123"
      },
      "payload": {
        "text": "Drafted the Nostr post. Want me to sign and publish it?",
        "parseMode": "Markdown"
      }
    }
  ],
  "events": [
    {
      "type": "audit.note",
      "message": "Nostr signing key not used; draft only."
    }
  ]
}
```

### Response `status` values

- `ok`
- `noop`
- `deferred`
- `error`

### Action types for initial implementation

Start with a very small set:

- `telegram.sendMessage`
- `telegram.sendTyping`
- `delegate.request`
- `audit.note`

Do not start with a broad arbitrary action system.

### Publishing approval rule

For social and Nostr workflows, the current operating rule is:

- agents may draft content
- agents may prepare content for signing
- agents may sign only within explicit signer policy
- agents may not publish externally without operator approval

For now, any externally visible Nostr post should be treated as approval-gated,
even if the draft and signing path are available.

## Delegation between runtimes

### Purpose

This allows:

- Bob to ask Stacks to do media/Nostr work
- Number 5 to ask Treasurer to evaluate or execute a financial action

### Endpoint

- `POST /v1/delegate`

### Request shape

```json
{
  "contractVersion": 1,
  "requestId": "2d2243d2-4363-4f55-a8b0-a5b9b7dd52e3",
  "caller": {
    "serviceId": "bob-runtime",
    "agentId": "orchestrator"
  },
  "callee": {
    "serviceId": "stacks-runtime",
    "agentId": "podcast_media"
  },
  "task": {
    "type": "nostr.publishDraft",
    "payload": {
      "draft": "Episode notes here",
      "requireApproval": true
    }
  },
  "origin": {
    "channel": "telegram",
    "botId": "bob",
    "userId": "1619231777"
  }
}
```

### Delegation rules

1. Caller must identify itself.
2. Callee must authenticate the caller.
3. High-risk actions must declare approval requirements in payload or policy.
4. Delegation should produce audit events.

### Nostr-specific approval interpretation

Until the operator loosens policy, treat Nostr actions as:

- `draft`: allowed within role
- `sign`: allowed only through the signer boundary and only for approved policy classes
- `publish`: requires explicit operator approval

This applies to both direct runtime requests and delegated requests.

## Secret rules

### Public ingress

Allowed:

- Telegram bot tokens
- ingress-to-runtime service tokens

Not allowed:

- Nostr private keys
- treasury signing keys
- high-value agent auth stores

### Private high-risk runtimes

Allowed:

- agent-specific signing keys
- runtime-specific service tokens
- agent-specific auth profiles

## Error handling

### Contract errors

Return:

- HTTP `400`
- structured error payload

### Auth errors

Return:

- HTTP `401` or `403`

### Runtime errors

Return:

- HTTP `500`
- include `requestId`
- no secret material in error text

## Logging and audit

Every request should log:

- `requestId`
- bot id
- agent id
- caller service
- callee service if delegated
- high-risk action types

Do not log:

- signing keys
- treasury secrets
- full bearer tokens

## Initial implementation recommendation

### Phase M2 output

The first implementation target should be:

- ingress receives `/telegram/stacks`
- ingress normalizes the Telegram update
- ingress forwards it to `stacks-runtime`
- `stacks-runtime` returns structured actions
- ingress performs Telegram send

This is the simplest contract that proves the architecture without introducing a
full mesh or queue.

### Why start with Stacks

- first real signing-key use case
- easiest justification for isolation
- smallest useful vertical slice

## Success criteria for M2

`M2` is complete when:

1. this contract is accepted as the working interface
2. ingress-to-runtime envelope is fixed enough to build against
3. action response model is fixed enough to build against
4. runtime-to-runtime delegation shape is fixed enough for Stacks and Treasurer

## Open questions deferred on purpose

These do not block M2:

1. whether the long-term async path uses a queue
2. whether every bot eventually gets its own runtime
3. whether isolated runtimes share a host or move to separate VMs
4. exact treasury approval semantics

Those are important, but the contract above is sufficient to start building the
first isolated runtime.
