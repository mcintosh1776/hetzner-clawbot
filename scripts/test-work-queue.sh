#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-91.107.207.3}"
SSH_KEY="${SSH_KEY:-/home/mcintosh/.ssh/mcintosh-clawbot}"
TENANT_ID="${TENANT_ID:-tenant_0}"
TASK_ID="${TASK_ID:-queue-harness-demo}"
SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
)

ssh "${SSH_OPTS[@]}" "root@${HOST}" bash -s -- "$TENANT_ID" "$TASK_ID" <<'REMOTE'
set -euo pipefail

tenant_id="$1"
task_id="$2"

pass() {
  printf 'PASS: %s\n' "$1"
}

rm -f "/opt/clawbot/tenants/${tenant_id}/work-queue/"*/"${task_id}.md"

create_json="$(
  clawbot-work-queue create "$tenant_id" "$task_id" \
    --title "Queue harness demo" \
    --owner steve \
    --category implementation \
    --state in_progress
)"
CREATE_JSON="$create_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["CREATE_JSON"])
if not payload.get("ok"):
    raise SystemExit("create did not return ok=true")
if not str(payload.get("path", "")).endswith("/in_progress/" + payload.get("task_id", "") + ".md"):
    raise SystemExit(f"unexpected create path: {payload.get('path')!r}")
PY
pass "queue create succeeds"

list_json="$(clawbot-work-queue list "$tenant_id" --owner steve)"
LIST_JSON="$list_json" TASK_ID="$task_id" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["LIST_JSON"])
task_id = os.environ["TASK_ID"]
tasks = payload.get("tasks") or []
if not any(item.get("task_id") == task_id for item in tasks):
    raise SystemExit(f"task {task_id!r} not present in owner-filtered list")
PY
pass "queue list filters by owner correctly"

handoff_json="$(
  clawbot-work-queue handoff "$tenant_id" "$task_id" \
    --to qa \
    --status ready_for_qa \
    --summary "First pass complete, ready for QA."
)"
HANDOFF_JSON="$handoff_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["HANDOFF_JSON"])
if payload.get("status") != "ready_for_qa":
    raise SystemExit(f"unexpected handoff status: {payload.get('status')!r}")
if payload.get("to") != "qa":
    raise SystemExit(f"unexpected handoff owner: {payload.get('to')!r}")
PY
pass "queue handoff moves task to qa state"

show_json="$(clawbot-work-queue show "$tenant_id" "$task_id")"
SHOW_JSON="$show_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["SHOW_JSON"])
task = payload.get("task") or {}
meta = task.get("meta") or {}
body = task.get("body") or ""
if task.get("state") != "ready_for_qa":
    raise SystemExit(f"unexpected show state: {task.get('state')!r}")
if meta.get("current_owner") != "qa":
    raise SystemExit(f"unexpected current_owner: {meta.get('current_owner')!r}")
if "## Latest handoff" not in body:
    raise SystemExit("handoff section missing from task body")
if "First pass complete, ready for QA." not in body:
    raise SystemExit("handoff summary missing from task body")
PY
pass "queue show preserves owner, state, and handoff body"

move_json="$(clawbot-work-queue move "$tenant_id" "$task_id" qa_failed --owner steve)"
MOVE_JSON="$move_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["MOVE_JSON"])
if payload.get("status") != "qa_failed":
    raise SystemExit(f"unexpected move status: {payload.get('status')!r}")
if payload.get("current_owner") != "steve":
    raise SystemExit(f"unexpected move owner: {payload.get('current_owner')!r}")
PY
pass "queue move updates state and owner explicitly"

printf 'PASS: work queue regression harness completed for %s\n' "$tenant_id"
REMOTE
