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
expected = {"shared", "bot-bob", "bot-stacks", "bot-jennifer", "bot-steve", "bot-number5"}
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

bob_positive="$(clawbot-qmd-tenant query "$tenant_id" bob "coordination boundaries")"
BOB_POSITIVE="$bob_positive" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["BOB_POSITIVE"])
allowed = payload.get("allowedCollections") or []
results = payload.get("results") or []
if allowed != ["shared", "bot-bob"]:
    raise SystemExit(f"unexpected bob allowed collections: {allowed}")
if not any("bob-coordination-boundaries-001" in str(item.get("file", "")) for item in results):
    raise SystemExit("bob positive lookup did not return bob-coordination-boundaries-001")
PY
pass "bob positive scoped query returns bob memory"

steve_positive="$(clawbot-qmd-tenant query "$tenant_id" steve "engineering discipline")"
STEVE_POSITIVE="$steve_positive" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STEVE_POSITIVE"])
allowed = payload.get("allowedCollections") or []
results = payload.get("results") or []
if allowed != ["shared", "bot-steve"]:
    raise SystemExit(f"unexpected steve allowed collections: {allowed}")
if not any("steve-engineering-discipline-001" in str(item.get("file", "")) for item in results):
    raise SystemExit("steve positive lookup did not return steve-engineering-discipline-001")
PY
pass "steve positive scoped query returns steve memory"

number5_positive="$(clawbot-qmd-tenant query "$tenant_id" number5 "business boundaries")"
NUMBER5_POSITIVE="$number5_positive" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["NUMBER5_POSITIVE"])
allowed = payload.get("allowedCollections") or []
results = payload.get("results") or []
if allowed != ["shared", "bot-number5"]:
    raise SystemExit(f"unexpected number5 allowed collections: {allowed}")
if not any("number5-business-boundaries-001" in str(item.get("file", "")) for item in results):
    raise SystemExit("number5 positive lookup did not return number5-business-boundaries-001")
PY
pass "number5 positive scoped query returns number5 memory"

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

steve_negative="$(clawbot-qmd-tenant query "$tenant_id" steve "business boundaries")"
STEVE_NEGATIVE="$steve_negative" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STEVE_NEGATIVE"])
results = payload.get("results") or []
if any("qmd://bot-number5/" in str(item.get("file", "")) for item in results):
    raise SystemExit(f"steve negative query leaked number5 memory: {results}")
PY
pass "steve cannot retrieve number5 bot-private memory"

number5_negative="$(clawbot-qmd-tenant query "$tenant_id" number5 "engineering discipline")"
NUMBER5_NEGATIVE="$number5_negative" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["NUMBER5_NEGATIVE"])
results = payload.get("results") or []
if any("qmd://bot-steve/" in str(item.get("file", "")) for item in results):
    raise SystemExit(f"number5 negative query leaked steve memory: {results}")
PY
pass "number5 cannot retrieve steve bot-private memory"

systemctl is-active --quiet clawbot-bob-memory.service
pass "clawbot-bob-memory.service is active"

systemctl is-active --quiet clawbot-stacks-memory.service
pass "clawbot-stacks-memory.service is active"

systemctl is-active --quiet clawbot-jennifer-memory.service
pass "clawbot-jennifer-memory.service is active"

systemctl is-active --quiet clawbot-steve-memory.service
pass "clawbot-steve-memory.service is active"

systemctl is-active --quiet clawbot-number5-memory.service
pass "clawbot-number5-memory.service is active"

bob_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-bob-runtime.container)"
stacks_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-stacks-runtime.container)"
jennifer_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-jennifer-runtime.container)"
steve_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-steve-runtime.container)"
number5_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-number5-runtime.container)"

bob_runtime_response="$(
  curl --silent --show-error \
    -H "Authorization: Bearer ${bob_token}" \
    -H 'Content-Type: application/json' \
    --data '{"event":{"messageId":123,"chat":{"id":456,"type":"private"},"sender":{"id":"1619231777","username":"mcintosh","firstName":"Mac"},"text":"what do you remember about coordination boundaries from memory"}}' \
    http://127.0.0.1:18920/v1/inbound/telegram
)"
BOB_RUNTIME_RESPONSE="$bob_runtime_response" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["BOB_RUNTIME_RESPONSE"])
actions = payload.get("actions") or []
text = (((actions[0] if actions else {}).get("message") or {}).get("text") or "").lower()
if "coordination" not in text and "routing" not in text:
    raise SystemExit(f"unexpected bob runtime reply: {text!r}")
PY
pass "bob runtime memory lookup answers from memory"

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

steve_runtime_response="$(
  curl --silent --show-error \
    -H "Authorization: Bearer ${steve_token}" \
    -H 'Content-Type: application/json' \
    --data '{"event":{"messageId":123,"chat":{"id":456,"type":"private"},"sender":{"id":"1619231777","username":"mcintosh","firstName":"Mac"},"text":"what do you remember about engineering discipline from memory"}}' \
    http://127.0.0.1:18923/v1/inbound/telegram
)"
STEVE_RUNTIME_RESPONSE="$steve_runtime_response" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STEVE_RUNTIME_RESPONSE"])
actions = payload.get("actions") or []
text = (((actions[0] if actions else {}).get("message") or {}).get("text") or "").lower()
if "engineering discipline" not in text and "migration safety" not in text:
    raise SystemExit(f"unexpected steve runtime reply: {text!r}")
PY
pass "steve runtime memory lookup answers from memory"

number5_runtime_response="$(
  curl --silent --show-error \
    -H "Authorization: Bearer ${number5_token}" \
    -H 'Content-Type: application/json' \
    --data '{"event":{"messageId":123,"chat":{"id":456,"type":"private"},"sender":{"id":"1619231777","username":"mcintosh","firstName":"Mac"},"text":"what do you remember about business boundaries from memory"}}' \
    http://127.0.0.1:18924/v1/inbound/telegram
)"
NUMBER5_RUNTIME_RESPONSE="$number5_runtime_response" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["NUMBER5_RUNTIME_RESPONSE"])
actions = payload.get("actions") or []
text = (((actions[0] if actions else {}).get("message") or {}).get("text") or "").lower()
if "business" not in text and "operational" not in text:
    raise SystemExit(f"unexpected number5 runtime reply: {text!r}")
PY
pass "number5 runtime memory lookup answers from memory"

printf 'PASS: memory pilot regression harness completed for %s\n' "$tenant_id"
REMOTE
