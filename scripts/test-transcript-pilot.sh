#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-91.107.207.3}"
SSH_KEY="${SSH_KEY:-/home/mcintosh/.ssh/mcintosh-clawbot}"
TENANT_ID="${TENANT_ID:-tenant_0}"
IMPORT_LIMIT="${IMPORT_LIMIT:-10}"
SSH_OPTS=(
  -i "$SSH_KEY"
  -o StrictHostKeyChecking=no
)

ssh "${SSH_OPTS[@]}" "root@${HOST}" bash -s -- "$TENANT_ID" "$IMPORT_LIMIT" <<'REMOTE'
set -euo pipefail

tenant_id="$1"
import_limit="$2"

pass() {
  printf 'PASS: %s\n' "$1"
}

rm -f "/opt/clawbot/tenants/${tenant_id}/memory/sources/transcripts/"*.md
import_json="$(clawbot-import-podcast-transcripts fetch-feed "$tenant_id" --limit "$import_limit")"
IMPORT_JSON="$import_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["IMPORT_JSON"])
imported = payload.get("imported") or []
if not payload.get("ok"):
    raise SystemExit("transcript importer did not return ok=true")
if len(imported) < 10:
    raise SystemExit(f"expected at least 10 imported transcript chunks, got {len(imported)}")
PY
pass "transcript importer fetched and normalized a live transcript batch"

rebuild_json="$(clawbot-qmd-tenant rebuild "$tenant_id" --embed)"
REBUILD_JSON="$rebuild_json" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["REBUILD_JSON"])
if not payload.get("ok"):
    raise SystemExit("wrapper rebuild did not return ok=true")
collections = payload.get("collections") or []
if "source-transcripts" not in collections:
    raise SystemExit(f"source-transcripts collection missing from rebuild output: {collections}")
PY
pass "transcript corpus is indexed into tenant-local QMD"

cypherpunk_query="$(clawbot-qmd-tenant query "$tenant_id" steve "Cypherpunk Manifesto")"
QUERIED="$cypherpunk_query" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["QUERIED"])
allowed = payload.get("allowedCollections") or []
results = payload.get("results") or []
if allowed != ["shared", "bot-steve", "source-transcripts"]:
    raise SystemExit(f"unexpected steve allowed collections: {allowed}")
if not any("qmd://source-transcripts/" in str(item.get("file", "")) for item in results):
    raise SystemExit(f"steve transcript retrieval returned no source-transcripts hits: {results}")
if not any("Cypherpunk" in str(item.get("snippet", "")) or "cypherpunk" in str(item.get("snippet", "")) for item in results):
    raise SystemExit(f"steve transcript retrieval did not surface cypherpunk snippets: {results}")
PY
pass "steve transcript retrieval returns cypherpunk transcript hits"

stacks_transcript_query="$(clawbot-qmd-tenant query "$tenant_id" stacks "Cypherpunk Manifesto")"
STACKS_QUERIED="$stacks_transcript_query" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STACKS_QUERIED"])
results = payload.get("results") or []
if any("qmd://source-transcripts/" in str(item.get("file", "")) for item in results):
    raise SystemExit(f"stacks unexpectedly retrieved transcript corpus results: {results}")
PY
pass "non-steve bots cannot retrieve source-transcripts results"

steve_token="$(sed -n 's/^Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=//p' /home/openclaw/.config/containers/systemd/clawbot-steve-runtime.container)"
steve_runtime_response="$(
  curl --silent --show-error \
    -H "Authorization: Bearer ${steve_token}" \
    -H 'Content-Type: application/json' \
    --data '{"event":{"messageId":123,"chat":{"id":456,"type":"private"},"sender":{"id":"1619231777","username":"mcintosh","firstName":"Mac"},"text":"what do you remember about the Cypherpunk Manifesto from memory"}}' \
    http://127.0.0.1:18923/v1/inbound/telegram
)"
STEVE_RUNTIME_RESPONSE="$steve_runtime_response" python3 - <<'PY'
import json
import os

payload = json.loads(os.environ["STEVE_RUNTIME_RESPONSE"])
actions = payload.get("actions") or []
text = (((actions[0] if actions else {}).get("message") or {}).get("text") or "").lower()
if "cypherpunk manifesto" not in text and "eric hughes" not in text:
    raise SystemExit(f"unexpected steve transcript runtime reply: {text!r}")
PY
pass "steve runtime answers transcript-backed cypherpunk query"

printf 'PASS: transcript pilot regression harness completed for %s\n' "$tenant_id"
REMOTE
