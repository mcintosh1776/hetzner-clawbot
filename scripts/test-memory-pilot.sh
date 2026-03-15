#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-91.107.207.3}"
SSH_KEY="${SSH_KEY:-/home/mcintosh/.ssh/mcintosh-clawbot}"
TENANT_ID="${TENANT_ID:-tenant_0}"
SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
)

ssh "${SSH_OPTS[@]}" "root@${HOST}" bash -s -- "$TENANT_ID" <<'REMOTE'
set -euo pipefail

tenant_id="$1"

pass() {
  printf 'PASS: %s\n' "$1"
}

status_json="$(clawbot-qmd-tenant status "$tenant_id")"
STATUS_JSON="$status_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STATUS_JSON"])
expected = {"shared", "bot-stacks", "bot-jennifer"}
collections = set(payload.get("collections") or [])
missing = sorted(expected - collections)
if missing:
    raise SystemExit(f"missing expected collections: {missing}")
PY
pass "tenant status exposes expected collections"

rebuild_json="$(clawbot-qmd-tenant rebuild "$tenant_id" --embed)"
REBUILD_JSON="$rebuild_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["REBUILD_JSON"])
if not payload.get("ok"):
    raise SystemExit("wrapper rebuild did not return ok=true")
PY
pass "tenant rebuild with embeddings succeeds"

stacks_positive="$(clawbot-qmd-tenant query "$tenant_id" stacks "warmer friendlier tone")"
STACKS_POSITIVE="$stacks_positive" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STACKS_POSITIVE"])
allowed = payload.get("allowedCollections") or []
results = payload.get("results") or []
if allowed != ["shared", "bot-stacks"]:
    raise SystemExit(f"unexpected stacks allowed collections: {allowed}")
if not any("stacks-social-warmth-001" in str(item.get("file", "")) for item in results):
    raise SystemExit("stacks positive lookup did not return stacks-social-warmth-001")
PY
pass "stacks positive scoped query returns stacks memory"

jennifer_positive="$(clawbot-qmd-tenant query "$tenant_id" jennifer "editorial discipline")"
JENNIFER_POSITIVE="$jennifer_positive" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["JENNIFER_POSITIVE"])
allowed = payload.get("allowedCollections") or []
results = payload.get("results") or []
if allowed != ["shared", "bot-jennifer"]:
    raise SystemExit(f"unexpected jennifer allowed collections: {allowed}")
if not any("jennifer-editorial-discipline-001" in str(item.get("file", "")) for item in results):
    raise SystemExit("jennifer positive lookup did not return jennifer-editorial-discipline-001")
PY
pass "jennifer positive scoped query returns jennifer memory"

stacks_negative="$(clawbot-qmd-tenant query "$tenant_id" stacks "evidence-minded framing")"
STACKS_NEGATIVE="$stacks_negative" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STACKS_NEGATIVE"])
results = payload.get("results") or []
if any("qmd://bot-jennifer/" in str(item.get("file", "")) for item in results):
    raise SystemExit(f"stacks negative query leaked jennifer memory: {results}")
PY
pass "stacks cannot retrieve jennifer bot-private memory"

jennifer_negative="$(clawbot-qmd-tenant query "$tenant_id" jennifer "warmer friendlier tone")"
JENNIFER_NEGATIVE="$jennifer_negative" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["JENNIFER_NEGATIVE"])
results = payload.get("results") or []
if any("qmd://bot-stacks/" in str(item.get("file", "")) for item in results):
    raise SystemExit(f"jennifer negative query leaked stacks memory: {results}")
PY
pass "jennifer cannot retrieve stacks bot-private memory"

systemctl is-active --quiet clawbot-stacks-memory.service
pass "clawbot-stacks-memory.service is active"

systemctl is-active --quiet clawbot-jennifer-memory.service
pass "clawbot-jennifer-memory.service is active"

stacks_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-stacks-runtime.container)"
jennifer_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-jennifer-runtime.container)"

stacks_runtime_response="$(
  curl --silent --show-error \
    -H "Authorization: Bearer ${stacks_token}" \
    -H 'Content-Type: application/json' \
    --data '{"event":{"messageId":123,"chat":{"id":456,"type":"private"},"sender":{"id":"1619231777","username":"mcintosh","firstName":"Mac"},"text":"what do you remember about warmer friendlier tone from memory"}}' \
    http://127.0.0.1:18921/v1/inbound/telegram
)"
STACKS_RUNTIME_RESPONSE="$stacks_runtime_response" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STACKS_RUNTIME_RESPONSE"])
actions = payload.get("actions") or []
text = (((actions[0] if actions else {}).get("message") or {}).get("text") or "").lower()
if "warmer" not in text or "robotic" not in text:
    raise SystemExit(f"unexpected stacks runtime reply: {text!r}")
PY
pass "stacks runtime memory lookup answers from memory"

jennifer_runtime_response="$(
  curl --silent --show-error \
    -H "Authorization: Bearer ${jennifer_token}" \
    -H 'Content-Type: application/json' \
    --data '{"event":{"messageId":123,"chat":{"id":456,"type":"private"},"sender":{"id":"1619231777","username":"mcintosh","firstName":"Mac"},"text":"what do you remember about editorial discipline from memory"}}' \
    http://127.0.0.1:18922/v1/inbound/telegram
)"
JENNIFER_RUNTIME_RESPONSE="$jennifer_runtime_response" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["JENNIFER_RUNTIME_RESPONSE"])
actions = payload.get("actions") or []
text = (((actions[0] if actions else {}).get("message") or {}).get("text") or "").lower()
if "evidence" not in text and "editorial discipline" not in text:
    raise SystemExit(f"unexpected jennifer runtime reply: {text!r}")
PY
pass "jennifer runtime memory lookup answers from memory"

printf 'PASS: memory pilot regression harness completed for %s\n' "$tenant_id"
REMOTE
