#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <agent-id> <topic-slug>" >&2
  exit 1
fi

agent_id="$1"
topic_slug="$2"
today="$(date +%F)"

cat <<EOF
# Proposal

## Agent

${agent_id}

## Topic

${topic_slug}

## Reason

Why this change is needed.

## Observed behavior

- 

## Proposed change

Describe the intended improvement.

## Target files

- 

## Suggested content

Provide exact text or a diff-style proposal.

## Risk

What could go wrong if this is accepted?

## Review notes

Draft created on ${today}.
EOF
