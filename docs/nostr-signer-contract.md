# Nostr Signer Contract

## Purpose

Define the boundary between bot runtimes and Nostr signing authority so private
keys never become ordinary runtime secrets or model-visible data.

This contract is intentionally narrow. It exists to support:

- `Stacks`
- `Jennifer`
- future signer-capable agents

without giving raw private-key access to those runtimes.

## Core rules

1. Private keys are sign-only.
2. Public keys are readable.
3. Private keys must never appear in:
   - prompts
   - chat replies
   - logs
   - memory
   - exports
   - debug output
4. Signing authority is not publishing authority.

## Current operator policy

For now, social publishing is approval-gated.

Allowed:

- draft posts
- prepare structured Nostr events
- check signer status
- read public key

Conditionally allowed:

- sign events, only through the signer service and only within explicit policy

Not allowed without explicit operator approval:

- publish to relays
- broadcast externally visible content
- post breaking-news or editorial material directly to the public

In short:

- draft: allowed
- sign: controlled
- publish: operator approval required

## Boundary design

### Runtime side

The runtime may call only signer capabilities such as:

- `GET /v1/nostr/status`
- `POST /v1/nostr/sign-event`

The runtime must not:

- read `nostr/privateKey`
- return private-key material
- persist private-key material

### Signer side

The signer service may:

- read the root-owned key material
- return configured status
- return public key
- sign well-formed events

The signer service must not:

- return the private key
- log the private key
- expose generic secret-read operations

## Auth model

- Each signer has its own internal bearer token.
- Each runtime receives only its own signer token.
- Tokens are rooted in the per-agent secret store.

## Logging rules

Allowed log fields:

- agent id
- runtime id
- signer action type
- event id
- public key
- timestamp
- approval status

Forbidden log fields:

- private key
- seed phrases
- raw secret blobs
- bearer tokens

## Approval model

### Draft

Drafting is a normal content action. It does not require publish approval.

### Sign

Signing is allowed only through the signer boundary. Signing does not imply
permission to publish.

### Publish

Publishing is a separate action and is approval-gated for now.

The intended operator flow is:

1. agent drafts post
2. agent presents draft to operator
3. operator approves or edits
4. agent signs approved content
5. later implementation may publish, but only after that approval step

## Rollout plan

### Phase 1

- signer status
- sign-only support
- no runtime publish path

### Phase 2

- explicit approval-aware publish path
- auditable publish records
- relay allowlists and event-kind policy

### Phase 3

- optional delegated or remote signer patterns if the trust boundary needs to move

