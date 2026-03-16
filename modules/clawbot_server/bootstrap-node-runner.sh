#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_BOOTSTRAP_LOG="${OPENCLAW_BOOTSTRAP_LOG:-/var/log/openclaw-node-bootstrap.log}"
if [[ -d /var/log ]]; then
  mkdir -p /var/log
  : > "$OPENCLAW_BOOTSTRAP_LOG"
  exec > >(tee -a "$OPENCLAW_BOOTSTRAP_LOG") 2>&1
fi

normalize_bool() {
  local value="${1:-false}"
  case "${value,,}" in
    1|true|yes|on)
      echo "true"
      ;;
    *)
      echo "false"
      ;;
 esac
}

OPENCLAW_USER="${OPENCLAW_USER:-}"
if [ -z "$OPENCLAW_USER" ]; then
  OPENCLAW_USER="openclaw"
fi

OPENCLAW_DIR="${OPENCLAW_DIR:-}"
if [ -z "$OPENCLAW_DIR" ]; then
  OPENCLAW_DIR="/srv/openclaw"
fi

OPENCLAW_BRANCH="${OPENCLAW_BRANCH:-}"
if [ -z "$OPENCLAW_BRANCH" ]; then
  OPENCLAW_BRANCH="main"
fi

OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-}"
if [ -z "$OPENCLAW_REPO_URL" ]; then
  OPENCLAW_REPO_URL="https://github.com/openclaw/openclaw.git"
fi

OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-}"
if [ -z "$OPENCLAW_IMAGE" ]; then
  OPENCLAW_IMAGE="localhost/openclaw:local"
fi

OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"
OPENCLAW_REQUIRE_OPT_VOLUME="${OPENCLAW_REQUIRE_OPT_VOLUME:-true}"
OPENCLAW_OPT_VOLUME_FSTYPE="${OPENCLAW_OPT_VOLUME_FSTYPE:-xfs}"
OPENCLAW_OPT_VOLUME_DEVICE="${OPENCLAW_OPT_VOLUME_DEVICE:-}"
OPENCLAW_OPT_VOLUME_ID="${OPENCLAW_OPT_VOLUME_ID:-}"
OPENCLAW_OPT_VOLUME_NAME="${OPENCLAW_OPT_VOLUME_NAME:-}"
OPENCLAW_OPT_VOLUME_WAIT_SECONDS="${OPENCLAW_OPT_VOLUME_WAIT_SECONDS:-180}"
OPENCLAW_ROOT_STATE_DIR="${OPENCLAW_ROOT_STATE_DIR:-/opt/clawbot-root}"
OPENCLAW_ROOT_SECRETS_DIR="${OPENCLAW_ROOT_SECRETS_DIR:-$OPENCLAW_ROOT_STATE_DIR/secrets}"
OPENCLAW_NOSTR_SIGNER_SOCKET_BASE_DIR="${OPENCLAW_NOSTR_SIGNER_SOCKET_BASE_DIR:-/opt/clawbot/state/nostr-signers}"
OPENCLAW_AGENT_PACK_REPO_URL="${OPENCLAW_AGENT_PACK_REPO_URL:-}"
OPENCLAW_AGENT_PACK_REF="${OPENCLAW_AGENT_PACK_REF:-main}"
OPENCLAW_AGENT_PACK_ROOT_DIR="${OPENCLAW_AGENT_PACK_ROOT_DIR:-$OPENCLAW_ROOT_STATE_DIR/agent-pack}"
OPENCLAW_AGENT_PACK_CHECKOUT_DIR="${OPENCLAW_AGENT_PACK_CHECKOUT_DIR:-$OPENCLAW_AGENT_PACK_ROOT_DIR/repo}"
OPENCLAW_AGENT_PACK_EXPORT_DIR_REL="${OPENCLAW_AGENT_PACK_EXPORT_DIR_REL:-exports/agent-config}"
OPENCLAW_AGENT_PACK_SSH_KEY_FILE="${OPENCLAW_AGENT_PACK_SSH_KEY_FILE:-$OPENCLAW_ROOT_STATE_DIR/bootstrap/agent-pack-deploy-key}"
OPENCLAW_AGENT_SECRET_PROVIDER="${OPENCLAW_AGENT_SECRET_PROVIDER:-/usr/local/bin/openclaw-agent-secret-provider}"
OPENCLAW_AGENT_SECRET_SUDOERS="${OPENCLAW_AGENT_SECRET_SUDOERS:-/etc/sudoers.d/openclaw-agent-secret-provider}"
OPENCLAW_OPERATOR_TELEGRAM_USER_ID="${OPENCLAW_OPERATOR_TELEGRAM_USER_ID:-}"
OPENCLAW_TENANT_ID="${OPENCLAW_TENANT_ID:-tenant_0}"
OPENCLAW_AGENT_SECRET_IDS=(orchestrator podcast_media research engineering business)
OPENCLAW_NOSTR_SIGNER_PUBLIC_IDS=(stacks jennifer)
OPENCLAW_PROPOSAL_PUBLIC_IDS=(bob stacks jennifer steve number5)
OPENCLAW_MEMORY_PUBLIC_IDS=(bob stacks jennifer steve number5)
OPENCLAW_AGENT_CONFIG_DIR="${OPENCLAW_AGENT_CONFIG_DIR:-/opt/clawbot/config/agent-config}"
OPENCLAW_LLM_SECRETS_FILE="/opt/clawbot/config/secrets/llm.env"
OPENCLAW_TELEGRAM_SECRETS_FILE="/opt/clawbot/config/secrets/telegram.env"
OPENCLAW_WEBHOOK_DIR="/opt/clawbot/config/telegram-webhook"
OPENCLAW_STACKS_RUNTIME_DIR="/opt/clawbot/config/stacks-runtime"
OPENCLAW_STACKS_RUNTIME_PORT="${OPENCLAW_STACKS_RUNTIME_PORT:-18921}"
OPENCLAW_STACKS_RUNTIME_MODEL="${OPENCLAW_STACKS_RUNTIME_MODEL:-openrouter/auto}"
OPENCLAW_STACKS_RUNTIME_SYSTEMD_UNIT="/etc/systemd/system/clawbot-stacks-runtime.service"
OPENCLAW_STACKS_RUNTIME_AGENT_ID="podcast_media"
OPENCLAW_STACKS_PROMPT_FILE="$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md"
OPENCLAW_PRIVATE_RUNTIME_BASE_DIR="${OPENCLAW_PRIVATE_RUNTIME_BASE_DIR:-/opt/clawbot/config/private-runtimes}"
OPENCLAW_TENANT_BASE_DIR="${OPENCLAW_TENANT_BASE_DIR:-/opt/clawbot/tenants/$OPENCLAW_TENANT_ID}"
OPENCLAW_TENANT_STATE_DIR="${OPENCLAW_TENANT_STATE_DIR:-$OPENCLAW_TENANT_BASE_DIR/state}"
OPENCLAW_TENANT_BOTS_STATE_DIR="${OPENCLAW_TENANT_BOTS_STATE_DIR:-$OPENCLAW_TENANT_STATE_DIR/bots}"
OPENCLAW_TENANT_MEMORY_DIR="${OPENCLAW_TENANT_MEMORY_DIR:-$OPENCLAW_TENANT_BASE_DIR/memory}"
OPENCLAW_TENANT_CANONICAL_MEMORY_DIR="${OPENCLAW_TENANT_CANONICAL_MEMORY_DIR:-$OPENCLAW_TENANT_MEMORY_DIR/canonical}"
OPENCLAW_TENANT_OBSERVATION_MEMORY_DIR="${OPENCLAW_TENANT_OBSERVATION_MEMORY_DIR:-$OPENCLAW_TENANT_MEMORY_DIR/observations}"
OPENCLAW_TENANT_RETRIEVAL_MEMORY_DIR="${OPENCLAW_TENANT_RETRIEVAL_MEMORY_DIR:-$OPENCLAW_TENANT_MEMORY_DIR/retrieval}"
OPENCLAW_TENANT_SESSION_MEMORY_DIR="${OPENCLAW_TENANT_SESSION_MEMORY_DIR:-$OPENCLAW_TENANT_MEMORY_DIR/session}"
OPENCLAW_TENANT_SOURCE_MEMORY_DIR="${OPENCLAW_TENANT_SOURCE_MEMORY_DIR:-$OPENCLAW_TENANT_MEMORY_DIR/sources}"
OPENCLAW_TENANT_TRANSCRIPT_SOURCE_DIR="${OPENCLAW_TENANT_TRANSCRIPT_SOURCE_DIR:-$OPENCLAW_TENANT_SOURCE_MEMORY_DIR/transcripts}"
OPENCLAW_QMD_WRAPPER="${OPENCLAW_QMD_WRAPPER:-/usr/local/bin/clawbot-qmd-tenant}"
OPENCLAW_TRANSCRIPT_IMPORTER="${OPENCLAW_TRANSCRIPT_IMPORTER:-/usr/local/bin/clawbot-import-podcast-transcripts}"
OPENCLAW_OBSERVATION_REVIEW_TOOL="${OPENCLAW_OBSERVATION_REVIEW_TOOL:-/usr/local/bin/clawbot-observation-review}"
OPENCLAW_QMD_NPM_PACKAGE="${OPENCLAW_QMD_NPM_PACKAGE:-@tobilu/qmd@2.0.1}"
OPENCLAW_QMD_NODE_MAJOR="${OPENCLAW_QMD_NODE_MAJOR:-22}"
OPENCLAW_PODCAST_RSS_FEED="${OPENCLAW_PODCAST_RSS_FEED:-https://serve.podhome.fm/rss/3d1d205b-b9f7-5253-b09d-df1c8ec4fc25}"
OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR="${OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR:-$OPENCLAW_TENANT_STATE_DIR/channels/telegram}"
OPENCLAW_PROPOSAL_SOCKET_BASE_DIR="${OPENCLAW_PROPOSAL_SOCKET_BASE_DIR:-$OPENCLAW_TENANT_BOTS_STATE_DIR}"
OPENCLAW_MEMORY_SOCKET_BASE_DIR="${OPENCLAW_MEMORY_SOCKET_BASE_DIR:-$OPENCLAW_TENANT_BOTS_STATE_DIR}"
OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR_LEGACY="${OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR_LEGACY:-/opt/clawbot/state/private-runtimes}"
OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR="${OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR:-$OPENCLAW_TENANT_BOTS_STATE_DIR}"
OPENCLAW_PRIVATE_RUNTIME_MODEL_DEFAULT="${OPENCLAW_PRIVATE_RUNTIME_MODEL_DEFAULT:-$OPENCLAW_STACKS_RUNTIME_MODEL}"
OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS=(bob stacks jennifer steve number5)
OPENCLAW_PRIVATE_RUNTIME_IMAGE="${OPENCLAW_PRIVATE_RUNTIME_IMAGE:-localhost/clawbot-private-runtime:local}"
OPENCLAW_PRIVATE_RUNTIME_CONTAINERFILE="${OPENCLAW_PRIVATE_RUNTIME_BASE_DIR}/Containerfile"
OPENCLAW_TENANT_REPOS_DIR="${OPENCLAW_TENANT_REPOS_DIR:-$OPENCLAW_TENANT_BASE_DIR/repos}"
OPENCLAW_AGENT_PROPOSAL_REPO_DIR_LEGACY="${OPENCLAW_AGENT_PROPOSAL_REPO_DIR_LEGACY:-/opt/clawbot/repos/clawbot-agents}"
OPENCLAW_AGENT_PROPOSAL_REPO_DIR="${OPENCLAW_AGENT_PROPOSAL_REPO_DIR:-$OPENCLAW_TENANT_REPOS_DIR/clawbot-agents}"
OPENCLAW_AGENT_PROPOSAL_HELPER="${OPENCLAW_AGENT_PROPOSAL_HELPER:-/usr/local/bin/clawbot-agents-pr}"
OPENCLAW_TLS_BACKUP_DIR="/opt/clawbot/tls/letsencrypt"
OPENCLAW_AGENT_FLEET_TEMPLATE_B64="${OPENCLAW_AGENT_FLEET_TEMPLATE_B64:-}"
OPENCLAW_ORCHESTRATOR_POLICY_TEMPLATE_B64="${OPENCLAW_ORCHESTRATOR_POLICY_TEMPLATE_B64:-}"
OPENCLAW_STACKS_TEMPLATE_B64="${OPENCLAW_STACKS_TEMPLATE_B64:-}"
OPENCLAW_JENNIFER_TEMPLATE_B64="${OPENCLAW_JENNIFER_TEMPLATE_B64:-}"
OPENCLAW_STEVE_TEMPLATE_B64="${OPENCLAW_STEVE_TEMPLATE_B64:-}"
OPENCLAW_BUSINESS_TEMPLATE_B64="${OPENCLAW_BUSINESS_TEMPLATE_B64:-}"
OPENCLAW_LLM_TEMPLATE_B64="${OPENCLAW_LLM_TEMPLATE_B64:-}"
OPENCLAW_PUBLIC_HOSTNAME="${OPENCLAW_PUBLIC_HOSTNAME:-}"
OPENCLAW_LETSENCRYPT_EMAIL="${OPENCLAW_LETSENCRYPT_EMAIL:-}"
OPENCLAW_ENABLE_WEBHOOK_PROXY="${OPENCLAW_ENABLE_WEBHOOK_PROXY:-false}"
OPENCLAW_ENABLE_WEBHOOK_PROXY="$(normalize_bool "$OPENCLAW_ENABLE_WEBHOOK_PROXY")"
OPENCLAW_WEBHOOK_RECEIVER_PORT="${OPENCLAW_WEBHOOK_RECEIVER_PORT:-9000}"
OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS_CSV="${OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS_CSV:-bob,stacks,jennifer,steve,number5}"
IFS=',' read -r -a OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS <<<"$OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS_CSV"
if [[ "${#OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS[@]}" -eq 0 ]]; then
  OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS=(bob stacks jennifer steve number5)
fi

BOOTSTRAP_MARKER="${BOOTSTRAP_MARKER:-}"
if [ -z "$BOOTSTRAP_MARKER" ]; then
  BOOTSTRAP_MARKER="/var/lib/clawbot/bootstrap.done"
fi

OPENCLAW_PARENT_DIR="${OPENCLAW_PARENT_DIR:-}"
if [ -z "$OPENCLAW_PARENT_DIR" ]; then
  OPENCLAW_PARENT_DIR="$(dirname "$OPENCLAW_DIR")"
fi

OPENCLAW_SWAP_FILE="${OPENCLAW_SWAP_FILE:-/swapfile}"
OPENCLAW_SWAP_SIZE_MB="${OPENCLAW_SWAP_SIZE_MB:-8192}"

log() {
  printf '[%s] [openclaw-bootstrap] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

ensure_swap() {
  local size_mb="${1:-8192}"
  local fstab_line="$OPENCLAW_SWAP_FILE none swap sw 0 0"

  if ! [ -f "$OPENCLAW_SWAP_FILE" ]; then
    dd if=/dev/zero of="$OPENCLAW_SWAP_FILE" bs=1M count="$size_mb" status=none
    chmod 600 "$OPENCLAW_SWAP_FILE"
    mkswap "$OPENCLAW_SWAP_FILE" >/dev/null
  fi

  if ! grep -Fqx "$fstab_line" /etc/fstab; then
    printf '%s\n' "$fstab_line" >> /etc/fstab
  fi

  if ! swapon --show=NAME --noheadings | grep -qx "$OPENCLAW_SWAP_FILE"; then
    swapon "$OPENCLAW_SWAP_FILE"
  fi
}

run_step() {
  local label="$1"
  shift
  log "START: $label"
  if "$@"; then
    log "OK: $label"
  else
    local rc=$?
    log "FAIL: $label (exit=$rc)"
    return "$rc"
  fi
}

wait_for_system_boot() {
  local max_attempts="${1:-180}"
  local interval_seconds="${2:-10}"
  local attempt=1

  if ! [[ "$interval_seconds" =~ ^[0-9]+$ ]] || (( interval_seconds < 1 )); then
    interval_seconds=10
  fi

  while (( attempt <= max_attempts )); do
    local boot_state
    boot_state="$(systemctl is-system-running 2>&1 | tr '\n' ' ' | sed 's/ *$//' || true)"

    case "${boot_state:-unknown}" in
      running|degraded|maintenance)
        log "Boot state is ${boot_state}; proceeding with bootstrap."
        return 0
        ;;
      *)
        ;;
    esac

    log "Waiting for system boot to settle (attempt $attempt/$max_attempts) state=${boot_state:-unknown}"
    sleep "$interval_seconds"
    ((attempt += 1))
  done

  log "Timed out waiting for system boot to reach a stable state; proceeding with bootstrap anyway."
  return 0
}

wait_for_sshd() {
  local max_attempts="${1:-30}"
  local attempt=1

  while (( attempt <= max_attempts )); do
    if systemctl is-active --quiet ssh; then
      if ! command -v ss >/dev/null 2>&1 || ss -ltn sport = :22 | grep -q ':22 '; then
        return 0
      fi
    fi

    log "Waiting for SSH listener on port 22 (attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt += 1))
  done

  log "Timed out waiting for SSH listener on port 22"
  return 1
}

wait_for_user_bus() {
  local max_attempts="${1:-30}"
  local attempt=1

  while (( attempt <= max_attempts )); do
    if [ -S "/run/user/$OPENCLAW_UID/bus" ] && run_as_openclaw_from_tmp systemctl --user is-active --quiet default.target; then
      return 0
    fi

    log "Waiting for rootless user bus for $OPENCLAW_USER (attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt += 1))
  done

  log "Timed out waiting for user bus for $OPENCLAW_USER"
  return 1
}

start_openclaw_user_slice() {
  local max_attempts="${1:-20}"
  local attempt=1

  while (( attempt <= max_attempts )); do
    if systemctl is-active --quiet "user@$OPENCLAW_UID.service"; then
      return 0
    fi

    run_as_openclaw_from_tmp systemctl --user is-active --quiet default.target >/dev/null 2>&1 || true
    if systemctl start "user@$OPENCLAW_UID.service" >/dev/null 2>&1; then
      return 0
    fi

    log "Retrying user service startup (attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt += 1))
  done

  log "Failed to start user@$OPENCLAW_UID.service"
  return 1
}

restart_openclaw_service() {
  local max_attempts="${1:-10}"
  local attempt=1

  while (( attempt <= max_attempts )); do
    if run_as_openclaw_from_tmp systemctl --user restart openclaw.service; then
      return 0
    fi

    log "Retrying openclaw.service restart (attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt += 1))
  done

  log "Failed to restart openclaw.service"
  return 1
}

read_existing_gateway_token() {
  if [[ ! -f /opt/clawbot/config/.env ]]; then
    echo ""
    return 0
  fi

  awk -F= 'BEGIN { token = "" } $1 == "OPENCLAW_GATEWAY_TOKEN" { token = $2; sub(/\r$/, "", token); print token; exit }' \
    /opt/clawbot/config/.env
}

ensure_gateway_token() {
  local desired_token
  local source="existing"
  local current_token
  local env_file="/opt/clawbot/config/.env"

  current_token="$(read_existing_gateway_token || true)"

  if [[ -n "$OPENCLAW_GATEWAY_TOKEN" ]]; then
    desired_token="$OPENCLAW_GATEWAY_TOKEN"
    source="input"
  elif [[ -n "$current_token" ]]; then
    desired_token="$current_token"
  else
    desired_token="$(openssl rand -hex 32 2>/dev/null || tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)"
    source="generated"
  fi

  if [[ ! -f "$env_file" || "$current_token" != "$desired_token" ]]; then
    if [[ -f "$env_file" ]]; then
      local temp_env
      temp_env="$(mktemp /tmp/openclaw_env.XXXXXX)"
      chmod 600 "$temp_env"
      awk -F= '!/^OPENCLAW_GATEWAY_TOKEN=/' "$env_file" > "$temp_env"
      printf "OPENCLAW_GATEWAY_TOKEN=%s\n" "$desired_token" >> "$temp_env"
      mv "$temp_env" "$env_file"
    else
      printf "OPENCLAW_GATEWAY_TOKEN=%s\n" "$desired_token" > "$env_file"
    fi
  fi

  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$env_file"
  chmod 600 "$env_file"
  log "Resolved gateway token from ${source}. Existing token present: $( [[ -n "$current_token" ]] && echo yes || echo no )"
}

prepare_bootstrap_directories() {
  mkdir -p \
    "$OPENCLAW_PARENT_DIR" \
    /opt/clawbot \
    /opt/clawbot/config \
    /opt/clawbot/config/secrets \
    /opt/clawbot/config/runtime \
    /opt/clawbot/work \
    /opt/clawbot/logs \
    /opt/clawbot/state \
    "/home/$OPENCLAW_USER/.config/containers/systemd"

  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER" "/home/$OPENCLAW_USER/.config/containers/systemd" /opt/clawbot
  chmod 750 /opt/clawbot /opt/clawbot/config /opt/clawbot/config/secrets /opt/clawbot/config/runtime /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state
}

prepare_root_secret_directories() {
  mkdir -p "$OPENCLAW_ROOT_STATE_DIR" "$OPENCLAW_ROOT_SECRETS_DIR"
  chown root:root "$OPENCLAW_ROOT_STATE_DIR" "$OPENCLAW_ROOT_SECRETS_DIR"
  chmod 700 "$OPENCLAW_ROOT_STATE_DIR" "$OPENCLAW_ROOT_SECRETS_DIR"
}

ensure_agent_secret_stores() {
  local agent_id
  local secret_store

  for agent_id in "${OPENCLAW_AGENT_SECRET_IDS[@]}"; do
    secret_store="$OPENCLAW_ROOT_SECRETS_DIR/${agent_id}.json"
    python3 - "$secret_store" "$agent_id" <<'PY'
import json
import secrets
import sys
from pathlib import Path

path = Path(sys.argv[1])
agent_id = sys.argv[2]
if path.exists():
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        payload = {}
else:
    payload = {}

if not isinstance(payload, dict):
    payload = {}

internal = payload.get("internal")
if not isinstance(internal, dict):
    internal = {}
    payload["internal"] = internal

if not isinstance(internal.get("apiToken"), str) or not internal["apiToken"].strip():
    internal["apiToken"] = secrets.token_urlsafe(32)

if not isinstance(internal.get("signerToken"), str) or not internal["signerToken"].strip():
    internal["signerToken"] = secrets.token_urlsafe(32)

if not isinstance(internal.get("proposalToken"), str) or not internal["proposalToken"].strip():
    internal["proposalToken"] = secrets.token_urlsafe(32)

diagnostics = payload.get("diagnostics")
if not isinstance(diagnostics, dict):
    diagnostics = {}
    payload["diagnostics"] = diagnostics

if not isinstance(diagnostics.get("testMarker"), str) or not diagnostics["testMarker"].strip():
    diagnostics["testMarker"] = f"agent:{agent_id}:ok"

path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

    chown root:root "$secret_store"
    chmod 600 "$secret_store"
  done
}

write_agent_secret_provider() {
  cat >"$OPENCLAW_AGENT_SECRET_PROVIDER" <<EOF
#!/usr/bin/env python3
import json
import sys
from pathlib import Path

ROOT = Path(${OPENCLAW_ROOT_SECRETS_DIR@Q})

def emit(payload, exit_code=0):
    sys.stdout.write(json.dumps(payload))
    sys.stdout.write("\\n")
    raise SystemExit(exit_code)

def lookup_secret(payload, secret_id):
    if isinstance(payload, dict) and secret_id in payload:
        return payload.get(secret_id)
    current = payload
    for part in secret_id.split("/"):
        if not isinstance(current, dict):
            return None
        current = current.get(part)
    return current

try:
    request = json.load(sys.stdin)
except Exception as exc:
    emit({"protocolVersion": 1, "values": {}, "errors": {"__request__": {"message": f"invalid request payload: {exc}"}}}, 1)

if request.get("protocolVersion") != 1:
    emit({"protocolVersion": 1, "values": {}, "errors": {"__request__": {"message": "unsupported protocolVersion"}}}, 1)

if len(sys.argv) != 2:
    emit({"protocolVersion": 1, "values": {}, "errors": {"__request__": {"message": "agent id argument required"}}}, 1)

agent_id = sys.argv[1]
store = ROOT / f"{agent_id}.json"

try:
    payload = json.loads(store.read_text(encoding="utf-8")) if store.exists() else {}
except Exception as exc:
    emit({"protocolVersion": 1, "values": {}, "errors": {"__store__": {"message": f"invalid secret store: {exc}"}}}, 1)

if not isinstance(payload, dict):
    emit({"protocolVersion": 1, "values": {}, "errors": {"__store__": {"message": "secret store must be a JSON object"}}}, 1)

values = {}
errors = {}

for secret_id in request.get("ids", []):
    value = lookup_secret(payload, secret_id)
    if isinstance(value, str) and value:
        values[secret_id] = value
    else:
        errors[secret_id] = {"message": "secret not found"}

response = {"protocolVersion": 1, "values": values}
if errors:
    response["errors"] = errors
    emit(response, 1)

emit(response, 0)
EOF

  chown root:root "$OPENCLAW_AGENT_SECRET_PROVIDER"
  chmod 750 "$OPENCLAW_AGENT_SECRET_PROVIDER"
}

write_agent_secret_sudoers() {
  cat >"$OPENCLAW_AGENT_SECRET_SUDOERS" <<EOF
Defaults!$OPENCLAW_AGENT_SECRET_PROVIDER !requiretty
$OPENCLAW_USER ALL=(root) NOPASSWD: $OPENCLAW_AGENT_SECRET_PROVIDER *
EOF

  chown root:root "$OPENCLAW_AGENT_SECRET_SUDOERS"
  chmod 440 "$OPENCLAW_AGENT_SECRET_SUDOERS"
}

prepare_runtime_config_directory() {
  mkdir -p /opt/clawbot/config/runtime
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" /opt/clawbot/config/runtime
  chmod 750 /opt/clawbot/config/runtime
}

prepare_default_agent_config_templates() {
  mkdir -p "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator" "$OPENCLAW_AGENT_CONFIG_DIR/specialists"
}

agent_workspace_host_dir() {
  local agent_id="$1"
  printf '/opt/clawbot/state/.openclaw/workspace-%s\n' "$agent_id"
}

sync_private_agent_pack_avatar() {
  local repo_dir="$1"
  local agent_id="$2"
  local source_dir="$repo_dir/agents/$agent_id/ASSETS"
  local workspace_dir
  local avatar_dir
  local source_file=""
  local source_name=""
  local target_name=""
  local existing

  workspace_dir="$(agent_workspace_host_dir "$agent_id")"
  avatar_dir="$workspace_dir/avatars"

  install -d -m 0750 -o "$OPENCLAW_USER" -g "$OPENCLAW_USER" "$workspace_dir" "$avatar_dir"

  shopt -s nullglob
  for existing in "$avatar_dir"/avatar.*; do
    rm -f "$existing"
  done
  shopt -u nullglob

  if [[ ! -d "$source_dir" ]]; then
    return 0
  fi

  shopt -s nullglob
  for existing in "$source_dir"/avatar.*; do
    source_file="$existing"
    source_name="$(basename "$existing")"
    break
  done
  shopt -u nullglob

  if [[ -z "$source_file" ]]; then
    return 0
  fi

  target_name="${source_name,,}"
  install -m 0640 -o "$OPENCLAW_USER" -g "$OPENCLAW_USER" "$source_file" "$avatar_dir/$target_name"
}

sync_private_agent_pack_avatars() {
  local repo_dir="$1"
  local agent_id

  for agent_id in orchestrator podcast_media research engineering business; do
    sync_private_agent_pack_avatar "$repo_dir" "$agent_id"
  done
}

render_openclaw_identity_json() {
  local agent_id="$1"
  local display_name="$2"
  local workspace_dir
  local avatar_path=""
  local avatar_file

  workspace_dir="$(agent_workspace_host_dir "$agent_id")"
  shopt -s nullglob
  for avatar_file in "$workspace_dir"/avatars/avatar.*; do
    avatar_path="avatars/$(basename "$avatar_file")"
    break
  done
  shopt -u nullglob

  if [[ -n "$avatar_path" ]]; then
    printf '{\n          "name": "%s",\n          "avatar": "%s"\n        }' "$display_name" "$avatar_path"
  else
    printf '{\n          "name": "%s"\n        }' "$display_name"
  fi
}

sync_private_agent_pack() {
  if [[ -z "$OPENCLAW_AGENT_PACK_REPO_URL" ]]; then
    return 0
  fi

  local repo_dir="$OPENCLAW_AGENT_PACK_CHECKOUT_DIR"
  local export_dir
  local -a git_prefix=()

  install -d -m 0700 "$OPENCLAW_AGENT_PACK_ROOT_DIR"

  if [[ "$OPENCLAW_AGENT_PACK_REPO_URL" == git@* || "$OPENCLAW_AGENT_PACK_REPO_URL" == ssh://* ]]; then
    if [[ ! -f "$OPENCLAW_AGENT_PACK_SSH_KEY_FILE" ]]; then
      echo "Private agent pack repo requires deploy key at $OPENCLAW_AGENT_PACK_SSH_KEY_FILE" >&2
      return 1
    fi
    chmod 600 "$OPENCLAW_AGENT_PACK_SSH_KEY_FILE"
    git_prefix=(
      env
      "GIT_SSH_COMMAND=ssh -i $OPENCLAW_AGENT_PACK_SSH_KEY_FILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    )
  fi

  rm -rf "$repo_dir"
  "${git_prefix[@]}" git clone --depth 1 --branch "$OPENCLAW_AGENT_PACK_REF" "$OPENCLAW_AGENT_PACK_REPO_URL" "$repo_dir"

  export_dir="$repo_dir/$OPENCLAW_AGENT_PACK_EXPORT_DIR_REL"
  if [[ ! -f "$export_dir/agent-fleet.yaml" ]]; then
    echo "Private agent pack export missing $OPENCLAW_AGENT_PACK_EXPORT_DIR_REL/agent-fleet.yaml" >&2
    return 1
  fi

  install -d -m 0750 -o "$OPENCLAW_USER" -g "$OPENCLAW_USER" \
    "$OPENCLAW_AGENT_CONFIG_DIR" \
    "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator" \
    "$OPENCLAW_AGENT_CONFIG_DIR/specialists"
  cp -a "$export_dir/." "$OPENCLAW_AGENT_CONFIG_DIR/"
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR"
  find "$OPENCLAW_AGENT_CONFIG_DIR" -type d -exec chmod 750 {} +
  find "$OPENCLAW_AGENT_CONFIG_DIR" -type f -exec chmod 640 {} +

  sync_private_agent_pack_avatars "$repo_dir"
}

prepare_rootless_runtime_directory() {
  mkdir -p "/run/user/$OPENCLAW_UID/containers"
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/run/user/$OPENCLAW_UID"
  chmod 700 "/run/user/$OPENCLAW_UID"
}

ensure_subid_mapping() {
  local file="$1"
  local entry="$2"

  if ! grep -q "^${entry}$" "$file"; then
    echo "$entry" >> "$file"
  fi
}

fix_webhook_deps() {
  run_as_openclaw "$OPENCLAW_WEBHOOK_DIR/.venv/bin/pip" install --upgrade --force-reinstall --no-cache-dir fastapi uvicorn httpx \
    >/tmp/openclaw-webhook-requirements.log 2>&1
}

log_pairing_command() {
  log "If a pairing request appears in the gateway UI, approve latest pending device with:"
  log "  sudo -u ${OPENCLAW_USER} bash -lc 'cd /home/${OPENCLAW_USER} && podman exec -it openclaw node dist/index.js devices approve --latest'"
}

mount_opt_volume_if_needed() {
  if [[ "$OPENCLAW_REQUIRE_OPT_VOLUME" != "true" ]]; then
    return 0
  fi

  local mount_point="/opt"
  local volume_device=""
  local attempt_sleep=3
  local candidates
  local attempts
  local attempts_taken=0
  local i
  local volume_uuid
  local volume_fstype
  local mount_fstype

  if mountpoint -q "$mount_point"; then
    return 0
  fi

  mkdir -p "$mount_point"

  candidates=()
  if [[ -n "$OPENCLAW_OPT_VOLUME_DEVICE" ]]; then
    candidates+=("$OPENCLAW_OPT_VOLUME_DEVICE")
  fi
  if [[ -n "$OPENCLAW_OPT_VOLUME_ID" ]]; then
    candidates+=("/dev/disk/by-id/scsi-0HC_Volume_${OPENCLAW_OPT_VOLUME_ID}")
  fi
  if [[ -n "$OPENCLAW_OPT_VOLUME_NAME" ]]; then
    candidates+=("/dev/disk/by-id/scsi-0HC_Volume_${OPENCLAW_OPT_VOLUME_NAME}")
  fi
  candidates+=("/dev/disk/by-id/scsi-0HC_Volume_*")
  if [[ -b /dev/sdb ]]; then
    candidates+=("/dev/sdb")
  fi
  if [[ -b /dev/vdb ]]; then
    candidates+=("/dev/vdb")
  fi

  resolve_volume() {
    local candidate
    local resolved
    for candidate in "${candidates[@]}"; do
      shopt -s nullglob
      for resolved in $candidate; do
        if [[ -b "$resolved" ]]; then
          echo "$resolved"
          return 0
        fi
      done
      shopt -u nullglob
    done
    return 1
  }

  if ! [[ "$OPENCLAW_OPT_VOLUME_WAIT_SECONDS" =~ ^[0-9]+$ ]]; then
    OPENCLAW_OPT_VOLUME_WAIT_SECONDS=180
  fi

  if [[ "$OPENCLAW_OPT_VOLUME_WAIT_SECONDS" -gt 0 ]]; then
    attempts=$((OPENCLAW_OPT_VOLUME_WAIT_SECONDS / attempt_sleep))
    if (( attempts < 1 )); then
      attempts=1
    fi

    for i in $(seq 1 "$attempts"); do
      attempts_taken=$i
      volume_device="$(resolve_volume || true)"
      if [[ -n "$volume_device" ]]; then
        break
      fi
      log "Waiting for persistent /opt volume to attach (attempt $i/$attempts)"
      sleep "$attempt_sleep"
    done
  else
    volume_device="$(resolve_volume || true)"
  fi

  if [[ -z "$volume_device" ]]; then
    log "Persistent /opt volume not found for openclaw bootstrap."
    return 1
  fi

  if [[ ! -b "$volume_device" ]]; then
    log "Expected a block device for /opt at $volume_device, got non-block target."
    return 1
  fi

  volume_fstype="$(blkid -o value -s TYPE "$volume_device" || true)"
  if [[ -z "$volume_fstype" ]]; then
    log "Formatting persistent volume $volume_device with ${OPENCLAW_OPT_VOLUME_FSTYPE}."
    mkfs -t "$OPENCLAW_OPT_VOLUME_FSTYPE" -F "$volume_device"
    volume_fstype="$OPENCLAW_OPT_VOLUME_FSTYPE"
  fi

  mount_fstype="$volume_fstype"
  if [[ "$mount_fstype" != "$OPENCLAW_OPT_VOLUME_FSTYPE" ]]; then
    log "Detected filesystem type $mount_fstype on $volume_device; mounting with detected type."
  fi

  volume_uuid="$(blkid -o value -s UUID "$volume_device" || true)"
  if [[ -z "$volume_uuid" ]]; then
    if ! mount "$volume_device" "$mount_point"; then
      log "Failed to mount $volume_device on $mount_point."
      return 1
    fi
  else
    if ! grep -q "UUID=$volume_uuid $mount_point " /etc/fstab; then
      echo "UUID=$volume_uuid $mount_point $mount_fstype defaults,noatime 0 2" >> /etc/fstab
    fi
    if ! mount "$mount_point"; then
      log "mount -a by /opt failed."
      return 1
    fi
  fi

  if ! mountpoint -q "$mount_point"; then
    log "/opt is still not mounted after mount operation."
    return 1
  fi

  log "Mounted persistent /opt volume from $volume_device after ${attempts_taken} attempt(s)."
}

assert_opt_volume_mount() {
  mount_opt_volume_if_needed
}

wait_for_image() {
  local image="$1"
  local max_attempts="${2:-30}"
  local attempt=1

  while (( attempt <= max_attempts )); do
    if run_as_openclaw podman image inspect "$image" >/dev/null 2>&1; then
      return 0
    fi

    log "Waiting for image $image to be available (attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt += 1))
  done

  log "Timed out waiting for image $image to become available"
  return 1
}

wait_for_openclaw_service() {
  local max_attempts="${1:-30}"
  local attempt=1

  while (( attempt <= max_attempts )); do
    if run_as_openclaw_from_tmp systemctl --user is-active --quiet openclaw.service; then
      return 0
    fi

    sleep 2
    ((attempt += 1))
  done

  run_as_openclaw_from_tmp systemctl --user status openclaw.service --no-pager || true
  log "Timed out waiting for openclaw.service to reach active state"
  return 1
}

validate_webhook_config() {
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    return 0
  fi

  if [[ -z "$OPENCLAW_PUBLIC_HOSTNAME" || -z "$OPENCLAW_LETSENCRYPT_EMAIL" ]]; then
    log "openclaw webhook proxy requires OPENCLAW_PUBLIC_HOSTNAME and OPENCLAW_LETSENCRYPT_EMAIL."
    return 1
  fi

  if [[ ! "$OPENCLAW_PUBLIC_HOSTNAME" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$ ]]; then
    log "OPENCLAW_PUBLIC_HOSTNAME '$OPENCLAW_PUBLIC_HOSTNAME' does not look like a valid hostname."
    return 1
  fi

  if [[ ! "$OPENCLAW_WEBHOOK_RECEIVER_PORT" =~ ^[0-9]+$ ]] || (( OPENCLAW_WEBHOOK_RECEIVER_PORT < 1 || OPENCLAW_WEBHOOK_RECEIVER_PORT > 65535 )); then
    log "OPENCLAW_WEBHOOK_RECEIVER_PORT '$OPENCLAW_WEBHOOK_RECEIVER_PORT' must be in the range 1-65535."
    return 1
  fi

  log "Resolved webhook hostname=${OPENCLAW_PUBLIC_HOSTNAME} receiver_port=${OPENCLAW_WEBHOOK_RECEIVER_PORT}"
}

ensure_webhook_secret() {
  local secret_file="$OPENCLAW_TELEGRAM_SECRETS_FILE"
  local webhook_secret

  if [[ ! -f "$secret_file" ]]; then
    webhook_secret="$(openssl rand -hex 24 2>/dev/null || tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)"
    {
      printf "TELEGRAM_WEBHOOK_SECRET=%s\n" "$webhook_secret"
    } > "$secret_file"
    chown "$OPENCLAW_USER:$OPENCLAW_USER" "$secret_file"
    chmod 600 "$secret_file"
    log "Created ${secret_file} with generated TELEGRAM_WEBHOOK_SECRET."
    return 0
  fi

  if grep -q '^TELEGRAM_WEBHOOK_SECRET=' "$secret_file"; then
    return 0
  fi

  if command -v openssl >/dev/null 2>&1; then
    webhook_secret="$(openssl rand -hex 24)"
  else
    webhook_secret="$(head -c 24 /dev/urandom | base64 | tr -d '=' | tr '+/' '-_' )"
  fi

  {
    printf "\nTELEGRAM_WEBHOOK_SECRET=%s\n" "$webhook_secret"
  } >> "$secret_file"
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$secret_file"
  chmod 600 "$secret_file"
  log "Added generated TELEGRAM_WEBHOOK_SECRET to ${secret_file}."
}

render_webhook_app() {
  cat >"${OPENCLAW_WEBHOOK_DIR}/app.py" <<'PY'
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path
import time
from pathlib import Path
from fastapi import FastAPI, Header, HTTPException, Request
import httpx

app = FastAPI()

ALLOWED_AGENTS = {"bob", "jennifer", "steve", "number5", "stacks"}
TELEGRAM_SECRET = os.getenv("TELEGRAM_WEBHOOK_SECRET", "")
OPENCLAW_WEBHOOK_TARGETS = {
  "bob": "http://127.0.0.1:18920/v1/inbound/telegram",
  "stacks": "http://127.0.0.1:18921/v1/inbound/telegram",
  "jennifer": "http://127.0.0.1:18922/v1/inbound/telegram",
  "steve": "http://127.0.0.1:18923/v1/inbound/telegram",
  "number5": "http://127.0.0.1:18924/v1/inbound/telegram",
}
OPENCLAW_AGENT_SECRET_PROVIDER = os.getenv("OPENCLAW_AGENT_SECRET_PROVIDER", "/usr/local/bin/openclaw-agent-secret-provider")
RUNTIME_AGENT_BY_PUBLIC_AGENT = {
  "bob": "orchestrator",
  "stacks": "podcast_media",
  "jennifer": "research",
  "steve": "engineering",
  "number5": "business",
}
TELEGRAM_TOKEN_ENV_BY_AGENT = {
  "bob": "TELEGRAM_BOT_TOKEN_BOB",
  "jennifer": "TELEGRAM_BOT_TOKEN_JENNIFER",
  "steve": "TELEGRAM_BOT_TOKEN_STEVE",
  "number5": "TELEGRAM_BOT_TOKEN_NUMBER5",
  "stacks": "TELEGRAM_BOT_TOKEN_STACKS",
}
OPERATOR_TELEGRAM_USER_ID = os.getenv("OPENCLAW_OPERATOR_TELEGRAM_USER_ID", "").strip()
PENDING_STATE_BASE_DIR = os.getenv("OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR", "/opt/clawbot/state/private-runtimes").strip()


def resolve_agent_secret(agent_id: str, secret_id: str) -> str:
  request_payload = json.dumps({"protocolVersion": 1, "ids": [secret_id]})
  try:
    completed = subprocess.run(
      ["sudo", "-n", OPENCLAW_AGENT_SECRET_PROVIDER, agent_id],
      input=request_payload,
      text=True,
      capture_output=True,
      check=True,
    )
  except subprocess.CalledProcessError as exc:
    detail = exc.stderr.strip() or exc.stdout.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"failed resolving agent secret for {agent_id}: {detail}") from exc

  try:
    payload = json.loads(completed.stdout or "{}")
  except json.JSONDecodeError as exc:
    raise HTTPException(status_code=502, detail=f"invalid secret response for {agent_id}: {exc}") from exc

  if payload.get("errors"):
    raise HTTPException(status_code=502, detail=f"agent secret lookup failed for {agent_id}: {payload['errors']}")

  value = payload.get("values", {}).get(secret_id)
  if not value:
    raise HTTPException(status_code=502, detail=f"agent secret {secret_id} unavailable for {agent_id}")
  return value


def normalize_inbound_request(agent: str, update: dict) -> dict:
  message = (
    update.get("message")
    or update.get("edited_message")
    or update.get("channel_post")
    or update.get("edited_channel_post")
    or {}
  )
  chat = message.get("chat") or {}
  sender = message.get("from") or {}
  return {
    "protocolVersion": 1,
    "channel": "telegram",
    "accountId": RUNTIME_AGENT_BY_PUBLIC_AGENT.get(agent, agent),
    "event": {
      "updateId": update.get("update_id"),
      "messageId": message.get("message_id"),
      "chat": {
        "id": chat.get("id"),
        "type": chat.get("type"),
      },
      "sender": {
        "id": sender.get("id"),
        "username": sender.get("username"),
        "firstName": sender.get("first_name"),
        "lastName": sender.get("last_name"),
      },
      "text": message.get("text"),
      "raw": update,
    },
  }


def normalize_text(value) -> str:
  return str(value or "").strip()


TELEGRAM_EVENT_MAX_AGE_SECONDS = 300
TELEGRAM_DEDUPE_STATE_DIR = os.getenv("OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR", "/opt/clawbot/tenants/tenant_0/state/channels/telegram").strip()


def telegram_message(update: dict) -> dict:
  return (
    update.get("message")
    or update.get("edited_message")
    or update.get("channel_post")
    or update.get("edited_channel_post")
    or {}
  )


def telegram_event_timestamp(update: dict) -> int | None:
  message = telegram_message(update)
  value = message.get("date")
  if value in (None, ""):
    return None
  try:
    return int(value)
  except Exception:
    return None


def telegram_update_id(update: dict) -> int | None:
  value = update.get("update_id")
  if value in (None, ""):
    return None
  try:
    return int(value)
  except Exception:
    return None


def telegram_dedupe_path(agent: str) -> str:
  return os.path.join(TELEGRAM_DEDUPE_STATE_DIR, f"{agent or 'unknown'}-last-update-id")


def is_stale_telegram_update(update: dict) -> bool:
  event_ts = telegram_event_timestamp(update)
  if event_ts is None:
    return False
  return event_ts < int(time.time()) - TELEGRAM_EVENT_MAX_AGE_SECONDS


def is_duplicate_telegram_update(update: dict, agent: str | None) -> bool:
  update_id = telegram_update_id(update)
  if update_id is None:
    return False
  os.makedirs(TELEGRAM_DEDUPE_STATE_DIR, exist_ok=True)
  path = telegram_dedupe_path(agent or "unknown")
  try:
    existing = int(Path(path).read_text(encoding="utf-8").strip())
  except Exception:
    existing = None
  if existing is not None and update_id <= existing:
    return True
  Path(path).write_text(f"{update_id}\n", encoding="utf-8")
  return False


def is_operator_reply_command(update: dict) -> bool:
  if not OPERATOR_TELEGRAM_USER_ID:
    return False
  message = telegram_message(update)
  sender = message.get("from") or {}
  sender_id = sender.get("id")
  if sender_id in (None, ""):
    return False
  if str(sender_id).strip() != OPERATOR_TELEGRAM_USER_ID:
    return False
  text = normalize_text(message.get("text")).lower()
  return (
    text in {"approve", "approve publish", "publish", "approved", "reject", "cancel", "deny", "discard"}
    or text.startswith("revise:")
    or text.startswith("edit:")
    or text.startswith("change:")
  )


def find_pending_owner(update: dict) -> str | None:
  message = telegram_message(update)
  chat = message.get("chat") or {}
  chat_id = chat.get("id")
  reply_to_message_id = ((message.get("reply_to_message") or {}).get("message_id"))
  if chat_id in (None, ""):
    return None

  candidates = []
  for public_agent in ALLOWED_AGENTS:
    state_dir = os.path.join(PENDING_STATE_BASE_DIR, public_agent)
    for filename in ("pending-proposal.json", "pending-nostr.json"):
      path = os.path.join(state_dir, filename)
      if not os.path.exists(path):
        continue
      try:
        with open(path, "r", encoding="utf-8") as handle:
          payload = json.load(handle)
      except Exception:
        continue
      if not isinstance(payload, dict):
        continue
      if payload.get("chatId") != chat_id:
        continue
      score = 1
      if reply_to_message_id not in (None, "") and payload.get("replyToMessageId") == reply_to_message_id:
        score = 2
      candidates.append((score, public_agent))

  if not candidates:
    return None
  candidates.sort(reverse=True)
  top_score = candidates[0][0]
  top_agents = [agent for score, agent in candidates if score == top_score]
  if len(top_agents) == 1:
    return top_agents[0]
  return None


async def send_telegram_message(agent: str, action: dict):
  token_env = TELEGRAM_TOKEN_ENV_BY_AGENT.get(agent)
  if not token_env:
    raise HTTPException(status_code=502, detail=f"no Telegram token mapping for runtime agent {agent}")

  bot_token = os.getenv(token_env, "")
  if not bot_token:
    raise HTTPException(status_code=502, detail=f"missing Telegram bot token for runtime agent {agent}")

  target = action.get("target") or {}
  message = action.get("message") or {}
  chat_id = target.get("chatId")
  text = message.get("text")
  if chat_id in (None, "") or not isinstance(text, str) or not text.strip():
    raise HTTPException(status_code=502, detail=f"incomplete telegram.sendMessage action for {agent}")

  payload = {
    "chat_id": chat_id,
    "text": text,
  }
  if target.get("replyToMessageId") not in (None, ""):
    payload["reply_to_message_id"] = target["replyToMessageId"]

  async with httpx.AsyncClient(timeout=15) as client:
    response = await client.post(
      f"https://api.telegram.org/bot{bot_token}/sendMessage",
      json=payload,
    )
    response.raise_for_status()


async def dispatch_runtime_actions(agent: str, payload: dict):
  actions = payload.get("actions") or []
  if not isinstance(actions, list):
    raise HTTPException(status_code=502, detail=f"runtime returned invalid action list for {agent}")

  for action in actions:
    if not isinstance(action, dict):
      continue
    action_type = action.get("type")
    if action_type == "telegram.sendMessage":
      await send_telegram_message(agent, action)
      continue
    raise HTTPException(status_code=502, detail=f"unsupported runtime action for {agent}: {action_type}")

async def forward_to_openclaw(update: dict, agent: str | None = None):
  if is_operator_reply_command(update):
    pending_owner = find_pending_owner(update)
    if pending_owner:
      agent = pending_owner

  if not agent:
    raise HTTPException(status_code=404, detail="agent-specific webhook path required")

  target_url = OPENCLAW_WEBHOOK_TARGETS.get(agent)
  if not target_url:
    raise HTTPException(status_code=404, detail="unknown agent")

  client_timeout = 90 if agent in RUNTIME_AGENT_BY_PUBLIC_AGENT else 10
  async with httpx.AsyncClient(timeout=client_timeout) as client:
    try:
      headers = {}
      runtime_agent_id = RUNTIME_AGENT_BY_PUBLIC_AGENT.get(agent)
      if runtime_agent_id:
        headers["authorization"] = f"Bearer {resolve_agent_secret(runtime_agent_id, 'internal/apiToken')}"
        response = await client.post(target_url, json=normalize_inbound_request(agent, update), headers=headers)
        response.raise_for_status()
        await dispatch_runtime_actions(agent, response.json() if response.content else {})
        return response

      if TELEGRAM_SECRET:
        headers["x-telegram-bot-api-secret-token"] = TELEGRAM_SECRET
      response = await client.post(target_url, json=update, headers=headers)
      if response.status_code == 404:
        raise HTTPException(status_code=502, detail=f"openclaw webhook route unavailable for {agent}")
      response.raise_for_status()
      return response
    except HTTPException:
      raise
    except httpx.HTTPError as exc:
      raise HTTPException(status_code=502, detail=f"telegram forward failed for {agent}: {exc}") from exc

async def handle_telegram_webhook(
  request: Request,
  agent: str | None = None,
  x_telegram_bot_api_secret_token: str | None = Header(default=None),
):
  if TELEGRAM_SECRET and x_telegram_bot_api_secret_token != TELEGRAM_SECRET:
    raise HTTPException(status_code=401, detail="invalid telegram secret token")

  if agent:
    agent = agent.lower()
    if agent not in ALLOWED_AGENTS:
      raise HTTPException(status_code=404, detail="unknown agent")

  try:
    raw_body = await request.body()
  except Exception as exc:
    raise HTTPException(status_code=400, detail=f"failed reading webhook body: {exc}")

  if not raw_body:
    return {"ok": True}

  try:
    update = json.loads(raw_body)
  except json.JSONDecodeError as exc:
    raise HTTPException(status_code=400, detail=f"invalid webhook JSON: {exc}")

  if not update:
    return {"ok": True}

  if is_stale_telegram_update(update):
    return {"ok": True, "ignored": "stale"}

  dedupe_agent = agent
  if not dedupe_agent and is_operator_reply_command(update):
    dedupe_agent = find_pending_owner(update)
  if is_duplicate_telegram_update(update, dedupe_agent or agent):
    return {"ok": True, "ignored": "duplicate"}

  await forward_to_openclaw(update, agent)
  return {"ok": True}


@app.post("/telegram")
@app.post("/telegram/{agent}")
@app.post("/telegram-webhook")
async def telegram_webhook(
  request: Request,
  agent: str | None = None,
  x_telegram_bot_api_secret_token: str | None = Header(default=None),
):
  return await handle_telegram_webhook(
    request=request,
    agent=agent,
    x_telegram_bot_api_secret_token=x_telegram_bot_api_secret_token,
  )
PY
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "${OPENCLAW_WEBHOOK_DIR}/app.py"
  chmod 640 "${OPENCLAW_WEBHOOK_DIR}/app.py"
}

write_webhook_systemd_unit() {


  cat >/etc/systemd/system/clawbot-telegram-webhook.service <<EOF
[Unit]
Description=Clawbot Telegram webhook relay
After=network-online.target
Wants=network-online.target

[Service]
User=$OPENCLAW_USER
Group=$OPENCLAW_USER
WorkingDirectory=$OPENCLAW_WEBHOOK_DIR
EnvironmentFile=$OPENCLAW_TELEGRAM_SECRETS_FILE
EnvironmentFile=-/opt/clawbot/config/.env
Environment=OPENCLAW_WEBHOOK_RECEIVER_PORT=$OPENCLAW_WEBHOOK_RECEIVER_PORT
Environment=OPENCLAW_AGENT_SECRET_PROVIDER=$OPENCLAW_AGENT_SECRET_PROVIDER
Environment=OPENCLAW_OPERATOR_TELEGRAM_USER_ID=$OPENCLAW_OPERATOR_TELEGRAM_USER_ID
Environment=OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR=$OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR
Environment=OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR=$OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR
Environment=OPENCLAW_STACKS_SECRET_AGENT_ID=$OPENCLAW_STACKS_RUNTIME_AGENT_ID
ExecStart=$OPENCLAW_WEBHOOK_DIR/.venv/bin/uvicorn app:app --host 127.0.0.1 --port $OPENCLAW_WEBHOOK_RECEIVER_PORT
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  chmod 0644 /etc/systemd/system/clawbot-telegram-webhook.service
}

configure_webhook_receiver() {
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    return 0
  fi

  if [[ ! -d "$OPENCLAW_WEBHOOK_DIR" ]]; then
    mkdir -p "$OPENCLAW_WEBHOOK_DIR"
  fi
  mkdir -p "$OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR"
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_WEBHOOK_DIR"
  chmod 750 "$OPENCLAW_WEBHOOK_DIR"
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR"
  chmod 750 "$OPENCLAW_TELEGRAM_DEDUPE_STATE_DIR"
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_WEBHOOK_DIR/.venv" 2>/dev/null || true

  if ! command -v python3 >/dev/null 2>&1; then
    log "Python not available on node; skipping webhook receiver setup."
    return 1
  fi

  if [[ ! -d "$OPENCLAW_WEBHOOK_DIR/.venv" ]]; then
    run_as_openclaw python3 -m venv "$OPENCLAW_WEBHOOK_DIR/.venv"
  fi

  if [[ ! -x "$OPENCLAW_WEBHOOK_DIR/.venv/bin/pip" ]]; then
    log "Webhook receiver virtualenv missing pip; reinstalling."
    run_as_openclaw python3 -m venv "$OPENCLAW_WEBHOOK_DIR/.venv"
  fi

  run_as_openclaw "$OPENCLAW_WEBHOOK_DIR/.venv/bin/pip" install --upgrade pip >/tmp/openclaw-venv-upgrade.log 2>&1 || true

  if [[ ! -s "$OPENCLAW_WEBHOOK_DIR/.venv/bin/uvicorn" ]] || ! run_as_openclaw "$OPENCLAW_WEBHOOK_DIR/.venv/bin/python" -c 'from uvicorn.config import Config; from fastapi import FastAPI; import httpx; print("deps-ok")' >/tmp/openclaw-webhook-import-check.log 2>&1; then
    run_step "Fix webhook deps" fix_webhook_deps
  fi
  render_webhook_app
  write_webhook_systemd_unit
  run_step "Reload systemd for webhook receiver" systemctl daemon-reload
  run_step "Enable webhook receiver service" systemctl enable --now clawbot-telegram-webhook.service
}

private_runtime_dir() {
  printf '%s/%s\n' "$OPENCLAW_PRIVATE_RUNTIME_BASE_DIR" "$1"
}

private_runtime_state_dir() {
  printf '%s/%s/runtime\n' "$OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR" "$1"
}

private_runtime_unit_name() {
  printf 'clawbot-%s-runtime.service\n' "$1"
}

private_runtime_container_name() {
  printf 'clawbot-%s-runtime\n' "$1"
}

private_runtime_quadlet_path() {
  printf '/home/%s/.config/containers/systemd/%s.container\n' "$OPENCLAW_USER" "$(private_runtime_container_name "$1")"
}

private_runtime_agent_id() {
  case "$1" in
    bob) echo "orchestrator" ;;
    stacks) echo "podcast_media" ;;
    jennifer) echo "research" ;;
    steve) echo "engineering" ;;
    number5) echo "business" ;;
    *) return 1 ;;
  esac
}

private_runtime_display_name() {
  case "$1" in
    bob) echo "Bob" ;;
    stacks) echo "Stacks" ;;
    jennifer) echo "Jennifer" ;;
    steve) echo "Steve" ;;
    number5) echo "Number 5" ;;
    *) return 1 ;;
  esac
}

private_runtime_prompt_file() {
  case "$1" in
    bob) echo "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator/policy.md" ;;
    stacks) echo "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" ;;
    jennifer) echo "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" ;;
    steve) echo "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" ;;
    number5) echo "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md" ;;
    *) return 1 ;;
  esac
}

private_runtime_port() {
  case "$1" in
    bob) echo "18920" ;;
    stacks) echo "18921" ;;
    jennifer) echo "18922" ;;
    steve) echo "18923" ;;
    number5) echo "18924" ;;
    *) return 1 ;;
  esac
}

render_private_runtime_app() {
  local runtime_dir="$1"
  cat >"${runtime_dir}/app.py" <<'PY'
import json
import os
import time
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException, Request
import httpx

app = FastAPI()

RUNTIME_AGENT_ID = os.getenv("OPENCLAW_PRIVATE_RUNTIME_AGENT_ID", "podcast_media")
RUNTIME_DISPLAY_NAME = os.getenv("OPENCLAW_PRIVATE_RUNTIME_DISPLAY_NAME", "Stacks")
RUNTIME_MODEL = os.getenv("OPENCLAW_PRIVATE_RUNTIME_MODEL", "openrouter/auto")
RUNTIME_PROMPT_FILE = os.getenv("OPENCLAW_PRIVATE_RUNTIME_PROMPT_FILE", "/opt/clawbot/config/agent-config/specialists/podcast_media.md")
OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_ID = os.getenv("OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_ID", "diagnostics/testMarker").strip()
OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_VALUE = os.getenv("OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_VALUE", "").strip()
OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_SOCKET = os.getenv("OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_SOCKET", "").strip()
OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_TOKEN = os.getenv("OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_TOKEN", "").strip()
OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_SOCKET = os.getenv("OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_SOCKET", "").strip()
OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_TOKEN = os.getenv("OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_TOKEN", "").strip()
OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET = os.getenv("OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET", "").strip()
OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN = os.getenv("OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN", "").strip()
OPENCLAW_PRIVATE_RUNTIME_STATE_DIR = os.getenv("OPENCLAW_PRIVATE_RUNTIME_STATE_DIR", "/runtime-state").strip()
OPENCLAW_PRIVATE_RUNTIME_OPERATOR_TELEGRAM_USER_ID = os.getenv("OPENCLAW_PRIVATE_RUNTIME_OPERATOR_TELEGRAM_USER_ID", "").strip()
OPENROUTER_BASE_URL = os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
OPENROUTER_HTTP_REFERER = os.getenv("OPENROUTER_HTTP_REFERER", "https://agents.satoshis-plebs.com/")
OPENROUTER_X_TITLE = os.getenv("OPENROUTER_X_TITLE", "clawbot-private-runtime")
OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")
OPENCLAW_PRIVATE_RUNTIME_API_TOKEN = os.getenv("OPENCLAW_PRIVATE_RUNTIME_API_TOKEN", "")
OUTPUT_POLICY = (
  "Return only the final Telegram reply text. "
  "Do not include titles, checklists, plans, internal notes, logs, or tool instructions."
)
NOSTR_DRAFT_POLICY = (
  "Return only the exact user-facing text of the Nostr post draft. "
  "No labels, no notes, no approval instructions, and no markdown fences."
)
NOSTR_PROFILE_POLICY = (
  "Return only a valid JSON object for a Nostr kind-0 profile metadata draft. "
  "No markdown fences, no labels, no notes, and no commentary."
)
PROPOSAL_POLICY = (
  "Return only a valid JSON object describing a Git-reviewed proposal for the private agent pack. "
  "No markdown fences, no labels, no commentary, and no extra text."
)


def normalize_model_name(model_name: str) -> str:
  if model_name.startswith("openrouter/"):
    return model_name.split("/", 1)[1]
  return model_name


def load_prompt() -> str:
  prompt_path = Path(RUNTIME_PROMPT_FILE)
  if not prompt_path.exists():
    return f"You are {RUNTIME_DISPLAY_NAME}. Reply concisely and helpfully."
  return prompt_path.read_text(encoding="utf-8")


def resolve_internal_api_token() -> str:
  if not OPENCLAW_PRIVATE_RUNTIME_API_TOKEN:
    raise RuntimeError("runtime api token missing")
  return OPENCLAW_PRIVATE_RUNTIME_API_TOKEN


def resolve_test_secret_marker() -> str:
  return OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_VALUE


def runtime_state_dir() -> Path:
  path = Path(OPENCLAW_PRIVATE_RUNTIME_STATE_DIR or "/runtime-state")
  path.mkdir(parents=True, exist_ok=True)
  return path


def pending_nostr_path() -> Path:
  return runtime_state_dir() / "pending-nostr.json"


def load_pending_nostr() -> dict | None:
  path = pending_nostr_path()
  if not path.exists():
    return None
  try:
    payload = json.loads(path.read_text(encoding="utf-8"))
  except Exception:
    return None
  return payload if isinstance(payload, dict) else None


def save_pending_nostr(payload: dict) -> None:
  pending_nostr_path().write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def clear_pending_nostr() -> None:
  path = pending_nostr_path()
  if path.exists():
    path.unlink()


def pending_proposal_path() -> Path:
  return runtime_state_dir() / "pending-proposal.json"


def load_pending_proposal() -> dict | None:
  path = pending_proposal_path()
  if not path.exists():
    return None
  try:
    payload = json.loads(path.read_text(encoding="utf-8"))
  except Exception:
    return None
  return payload if isinstance(payload, dict) else None


def save_pending_proposal(payload: dict) -> None:
  pending_proposal_path().write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def clear_pending_proposal() -> None:
  path = pending_proposal_path()
  if path.exists():
    path.unlink()


def last_opened_proposal_path() -> Path:
  return runtime_state_dir() / "last-opened-proposal.json"


def load_last_opened_proposal() -> dict | None:
  path = last_opened_proposal_path()
  if not path.exists():
    return None
  try:
    payload = json.loads(path.read_text(encoding="utf-8"))
  except Exception:
    return None
  return payload if isinstance(payload, dict) else None


def save_last_opened_proposal(payload: dict) -> None:
  last_opened_proposal_path().write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def nostr_signer_configured() -> bool:
  return bool(OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_SOCKET and OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_TOKEN)


def proposal_service_configured() -> bool:
  return bool(OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_SOCKET and OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_TOKEN)


def memory_service_configured() -> bool:
  return bool(OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET and OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN)


async def request_nostr_signer(method: str, path: str, payload: dict | None = None) -> dict:
  if not nostr_signer_configured():
    raise HTTPException(status_code=503, detail=f"nostr signer not configured for {RUNTIME_DISPLAY_NAME}")

  transport = httpx.AsyncHTTPTransport(uds=OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_SOCKET)
  try:
    async with httpx.AsyncClient(
      transport=transport,
      base_url="http://nostr-signer",
      timeout=30,
    ) as client:
      response = await client.request(
        method,
        path,
        headers={"Authorization": f"Bearer {OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_TOKEN}"},
        json=payload,
      )
      response.raise_for_status()
  except httpx.HTTPStatusError as exc:
    detail = exc.response.text.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"nostr signer request failed: {detail}") from exc
  except httpx.HTTPError as exc:
    raise HTTPException(status_code=502, detail=f"nostr signer unavailable: {exc}") from exc

  try:
    return response.json()
  except Exception as exc:
    raise HTTPException(status_code=502, detail=f"invalid nostr signer response: {exc}") from exc


async def request_proposal_service(method: str, path: str, payload: dict | None = None) -> dict:
  if not proposal_service_configured():
    raise HTTPException(status_code=503, detail=f"proposal service not configured for {RUNTIME_DISPLAY_NAME}")

  transport = httpx.AsyncHTTPTransport(uds=OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_SOCKET)
  try:
    async with httpx.AsyncClient(
      transport=transport,
      base_url="http://proposal-service",
      timeout=30,
    ) as client:
      response = await client.request(
        method,
        path,
        headers={"Authorization": f"Bearer {OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_TOKEN}"},
        json=payload,
      )
      response.raise_for_status()
  except httpx.HTTPStatusError as exc:
    detail = exc.response.text.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"proposal service request failed: {detail}") from exc
  except httpx.HTTPError as exc:
    raise HTTPException(status_code=502, detail=f"proposal service unavailable: {exc}") from exc

  try:
    return response.json()
  except Exception as exc:
    raise HTTPException(status_code=502, detail=f"invalid proposal service response: {exc}") from exc


async def request_memory_service(query_text: str) -> dict:
  if not memory_service_configured():
    raise HTTPException(status_code=503, detail=f"memory service not configured for {RUNTIME_DISPLAY_NAME}")

  transport = httpx.AsyncHTTPTransport(uds=OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET)
  try:
    async with httpx.AsyncClient(
      transport=transport,
      base_url="http://memory-service",
      timeout=20,
    ) as client:
      response = await client.post(
        "/v1/memory/query",
        headers={"Authorization": f"Bearer {OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN}"},
        json={"query": query_text},
      )
      response.raise_for_status()
  except httpx.HTTPStatusError as exc:
    detail = exc.response.text.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"memory service request failed: {detail}") from exc
  except httpx.HTTPError as exc:
    raise HTTPException(status_code=502, detail=f"memory service unavailable: {exc}") from exc

  try:
    return response.json()
  except Exception as exc:
    raise HTTPException(status_code=502, detail=f"invalid memory service response: {exc}") from exc


async def request_memory_observation_create(content_text: str) -> dict:
  if not memory_service_configured():
    raise HTTPException(status_code=503, detail=f"memory service not configured for {RUNTIME_DISPLAY_NAME}")

  transport = httpx.AsyncHTTPTransport(uds=OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET)
  try:
    async with httpx.AsyncClient(
      transport=transport,
      base_url="http://memory-service",
      timeout=20,
    ) as client:
      response = await client.post(
        "/v1/memory/observations",
        headers={"Authorization": f"Bearer {OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN}"},
        json={"content": content_text},
      )
      response.raise_for_status()
  except httpx.HTTPStatusError as exc:
    detail = exc.response.text.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"memory service request failed: {detail}") from exc
  except httpx.HTTPError as exc:
    raise HTTPException(status_code=502, detail=f"memory service unavailable: {exc}") from exc

  try:
    return response.json()
  except Exception as exc:
    raise HTTPException(status_code=502, detail=f"invalid memory service response: {exc}") from exc


def build_user_message(payload: dict) -> str:
  event = payload.get("event") or {}
  sender = event.get("sender") or {}
  first_name = sender.get("firstName") or "unknown"
  username = sender.get("username") or "unknown"
  text = event.get("text") or ""
  return (
    f"Telegram message for {RUNTIME_DISPLAY_NAME}.\n"
    f"Sender: {first_name} (@{username})\n"
    f"Chat ID: {event.get('chat', {}).get('id')}\n"
    f"Message text:\n{text}"
  )


async def generate_reply(payload: dict, extra_instruction: str = "") -> str:
  if not OPENROUTER_API_KEY:
    raise HTTPException(status_code=500, detail=f"OPENROUTER_API_KEY is not configured for {RUNTIME_DISPLAY_NAME} runtime")

  system_content = f"{load_prompt()}\n\n{OUTPUT_POLICY}"
  if extra_instruction.strip():
    system_content = f"{system_content}\n\n{extra_instruction.strip()}"

  messages = [
    {"role": "system", "content": system_content},
    {"role": "user", "content": build_user_message(payload)},
  ]

  async with httpx.AsyncClient(timeout=90) as client:
    response = await client.post(
      f"{OPENROUTER_BASE_URL.rstrip('/')}/chat/completions",
      headers={
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": OPENROUTER_HTTP_REFERER,
        "X-Title": OPENROUTER_X_TITLE,
      },
      json={
        "model": normalize_model_name(RUNTIME_MODEL),
        "messages": messages,
        "temperature": 0.3,
      },
    )
    response.raise_for_status()

  data = response.json()
  try:
    content = data["choices"][0]["message"]["content"]
  except (KeyError, IndexError, TypeError) as exc:
    raise HTTPException(status_code=502, detail=f"invalid OpenRouter response: {exc}") from exc

  if isinstance(content, list):
    return "\n".join(
      item.get("text", "")
      for item in content
      if isinstance(item, dict) and item.get("text")
    ).strip()
  return str(content).strip()


def sender_is_operator(event: dict) -> bool:
  sender = event.get("sender") or {}
  sender_id = sender.get("id")
  if sender_id in (None, "") or not OPENCLAW_PRIVATE_RUNTIME_OPERATOR_TELEGRAM_USER_ID:
    return False
  return str(sender_id).strip() == OPENCLAW_PRIVATE_RUNTIME_OPERATOR_TELEGRAM_USER_ID


def normalize_text(value) -> str:
  return str(value or "").strip()


def is_approval_command(text: str) -> bool:
  return normalize_text(text).lower() in {"approve", "approve publish", "publish", "approved"}


def is_reject_command(text: str) -> bool:
  return normalize_text(text).lower() in {"reject", "cancel", "deny", "discard"}


def revision_instruction(text: str) -> str:
  value = normalize_text(text)
  for prefix in ("revise:", "edit:", "change:"):
    if value.lower().startswith(prefix):
      return value[len(prefix):].strip()
  return ""


def contains_any_phrase(text: str, phrases: tuple[str, ...]) -> bool:
  return any(phrase in text for phrase in phrases)


def looks_like_meta_agent_conversation(text: str) -> bool:
  lowered = normalize_text(text).lower()
  meta_phrases = (
    "proposal",
    "propose",
    "pull request",
    "merge request",
    "open a pr",
    "open pr",
    "open a proposal",
    "repo proposal",
    "agent-pack",
    "agent pack",
    "guidance",
    "feedback file",
    "social_posting.md",
    "feedback.md",
    "agent.md",
    "prompt",
    "workflow",
    "behavior",
    "tone",
    "voice",
    "private instructions",
    "private repo",
    "update your guidance",
    "update your prompt",
    "update your repo",
    "conversation with me",
    "our conversation",
  )
  return contains_any_phrase(lowered, meta_phrases)


def looks_like_feedback_proposal_request(text: str) -> bool:
  return looks_like_meta_agent_conversation(text)


def looks_like_memory_lookup_request(text: str) -> bool:
  lowered = normalize_text(text).lower()
  phrases = (
    "search memory",
    "check memory",
    "look in memory",
    "memory lookup",
    "what do you remember",
    "from memory",
    "recall from memory",
  )
  return contains_any_phrase(lowered, phrases)


def looks_like_observation_memory_request(text: str) -> bool:
  lowered = normalize_text(text).lower()
  prefixes = (
    "remember this:",
    "remember this for later:",
    "store observation:",
    "store this observation:",
    "save observation:",
    "save this observation:",
  )
  return any(lowered.startswith(prefix) for prefix in prefixes)


def normalize_memory_lookup_query(text: str) -> str:
  value = normalize_text(text)
  lowered = value.lower()
  replacements = (
    "search memory for",
    "search memory",
    "check memory for",
    "check memory",
    "look in memory for",
    "look in memory",
    "memory lookup for",
    "memory lookup",
    "what do you remember about",
    "what do you remember",
    "recall from memory about",
    "recall from memory",
    "from memory",
  )
  for phrase in replacements:
    if lowered.startswith(phrase):
      value = value[len(phrase):].strip(" :.-\n\t")
      lowered = value.lower()
      break
  if lowered.endswith("from memory"):
    value = value[: -len("from memory")].strip(" :.-\n\t")
  if lowered.endswith("in memory"):
    value = value[: -len("in memory")].strip(" :.-\n\t")
  return value or normalize_text(text)


def normalize_observation_memory_content(text: str) -> str:
  value = normalize_text(text)
  lowered = value.lower()
  prefixes = (
    "remember this:",
    "remember this for later:",
    "store observation:",
    "store this observation:",
    "save observation:",
    "save this observation:",
  )
  for prefix in prefixes:
    if lowered.startswith(prefix):
      return value[len(prefix):].strip()
  return value


def looks_like_nostr_publish_request(text: str) -> bool:
  lowered = normalize_text(text).lower()
  if looks_like_meta_agent_conversation(lowered):
    return False
  social_channel_phrases = ("nostr", "social media", "twitter", "x ", " x/", "mastodon", "toot")
  social_artifact_phrases = ("post", "publish", "announcement", "thread", "note", "reply", "share", "tweet", "toot")
  return contains_any_phrase(lowered, social_channel_phrases) and contains_any_phrase(lowered, social_artifact_phrases)


def looks_like_nostr_profile_request(text: str) -> bool:
  lowered = normalize_text(text).lower()
  if looks_like_meta_agent_conversation(lowered):
    return False
  social_channel_phrases = ("nostr", "social media", "twitter", "x ", " x/", "mastodon")
  profile_phrases = ("profile", "bio", "about", "metadata", "display name", "kind 0")
  return contains_any_phrase(lowered, social_channel_phrases) and contains_any_phrase(lowered, profile_phrases)


def build_nostr_draft_instruction(payload: dict, revision_note: str = "", previous_draft: str = "") -> str:
  event = payload.get("event") or {}
  request_text = normalize_text(event.get("text"))
  instruction_lines = [
    NOSTR_DRAFT_POLICY,
    "Write one complete Nostr post in plain text.",
    "Keep it concise and publication-ready.",
    "Never use placeholders such as [topic], [guest], [time], [link], TODO, or angle brackets.",
    "Do not invent facts, quotes, guests, dates, links, or episode details that are not clearly present in the request or prompt context.",
    "If specifics are missing, write a truthful high-signal draft that stays generic without sounding empty.",
    "Use at most two hashtags, and only when they genuinely add value.",
    "Do not mention approvals, drafts, internal process, or that publishing is disabled.",
  ]

  if RUNTIME_AGENT_ID == "podcast_media":
    instruction_lines.extend([
      "Write like a sharp podcast/media operator promoting a real episode or segment.",
      "Favor crisp promotional copy, specific listener value, and a clean call to engage.",
      "Avoid hype, filler, or generic marketing language.",
    ])
  elif RUNTIME_AGENT_ID == "research":
    instruction_lines.extend([
      "Write like a careful editorial/news specialist.",
      "Favor factual framing, clarity, and restrained confidence.",
      "Avoid hype, speculation, and vague editorial filler.",
    ])

  if request_text:
    instruction_lines.append(f"Request context:\n{request_text}")

  if revision_note:
    instruction_lines.extend([
      "Revise the existing draft using the operator feedback below.",
      f"Existing draft:\n{previous_draft}",
      f"Operator feedback:\n{revision_note}",
    ])

  return "\n\n".join(instruction_lines)


def build_nostr_profile_instruction(payload: dict, revision_note: str = "", previous_profile: str = "") -> str:
  event = payload.get("event") or {}
  request_text = normalize_text(event.get("text"))
  instruction_lines = [
    NOSTR_PROFILE_POLICY,
    "Return a JSON object only.",
    "Do not wrap the JSON in markdown, code fences, labels, or explanation.",
    "The first character of the response must be { and the last character must be }.",
    "Allowed fields include: name, display_name, about, website, picture, banner, nip05, lud16.",
    "Only include fields you can justify from the request and agent identity context.",
    "Do not invent picture URLs, websites, nip05 values, or lightning addresses.",
    "If a field is unknown, omit it instead of fabricating it.",
    "Keep the profile aligned with the agent's actual identity, role, and public posture.",
    "Do not mention approvals, drafts, internal process, or implementation details.",
    "Do not include private keys, tokens, or secret references.",
  ]

  if RUNTIME_AGENT_ID == "podcast_media":
    instruction_lines.extend([
      "Write Stacks as a Bitcoin-first podcast/media operator.",
      "The profile should feel public-facing, credible, concise, and promotional without hype.",
      "Do not describe Bitcoin work as crypto work unless non-Bitcoin systems are explicitly part of the remit.",
    ])
  elif RUNTIME_AGENT_ID == "research":
    instruction_lines.extend([
      "Write Jennifer as a Bitcoin-first research, editorial, and news specialist.",
      "The profile should feel sharp, evidence-aware, and publication-capable without sounding stiff.",
      "Do not use generalized crypto framing for Bitcoin-first editorial work.",
    ])

  if request_text:
    instruction_lines.append(f"Request context:\n{request_text}")

  if revision_note:
    instruction_lines.extend([
      "Revise the existing profile draft using the operator feedback below.",
      f"Existing profile draft:\n{previous_profile}",
      f"Operator feedback:\n{revision_note}",
    ])

  return "\n\n".join(instruction_lines)


def build_feedback_proposal_instruction(payload: dict, revision_note: str = "", previous_body: str = "") -> str:
  event = payload.get("event") or {}
  request_text = normalize_text(event.get("text"))
  instruction_lines = [
    PROPOSAL_POLICY,
    "Return a JSON object only.",
    "The JSON must include exactly these keys: topicSlug, summary, previewMarkdown, files.",
    "topicSlug must be lowercase letters, numbers, and hyphens only.",
    "summary must be a short one-line description.",
    "previewMarkdown must be a short markdown summary of the exact file changes for operator review.",
    "files must be a non-empty JSON array of objects with keys path and content.",
    f"Every files[].path must stay under agents/{RUNTIME_AGENT_ID}/ and must target a markdown file in that agent's own directory tree.",
    "Every files[].content must be the full replacement content for that file after the change.",
    "Do not propose edits to shared files, exports, scripts, or infrastructure files.",
    "Prefer editing AGENT.md, SOUL.md, FEEDBACK.md, IDENTITY.md, MEMORY.md, RELATIONSHIPS.md, or markdown files under SKILLS/ for this agent.",
    "The proposed edits should directly implement the requested improvement to agent behavior, guidance, or publishing quality.",
    "Do not mention private keys, secrets, or infrastructure details.",
    "Do not emit markdown fences or extra commentary outside the JSON object.",
  ]
  if request_text:
    instruction_lines.append(f"Request context:\n{request_text}")
  if revision_note:
    instruction_lines.extend([
      "Revise the existing proposal using the operator feedback below.",
      f"Existing proposal preview:\n{previous_body}",
      f"Operator feedback:\n{revision_note}",
    ])
  return "\n\n".join(instruction_lines)


def approval_message(draft: str, draft_id: str, draft_type: str = "post") -> str:
  label = "Profile draft" if draft_type == "profile" else "Draft"
  approval_target = "publish it"
  tail = "Approved drafts will be signed and published to the configured relay set."
  return (
    f"{label} ready for approval ({draft_id}).\n\n"
    f"{draft}\n\n"
    f"Reply `approve` to {approval_target}. "
    "Reply `reject` to discard it. "
    "Reply `revise: <changes>` to request a revision. "
    f"{tail}"
  )


def signed_ack_message(result: dict, draft_type: str = "post") -> str:
  nostr = result.get("nostr") or {}
  event = nostr.get("event") or {}
  published = nostr.get("published") or {}
  published_ok = published.get("published") is True
  relay_results = published.get("results") or []
  accepted_relays = [item.get("relay", "") for item in relay_results if item.get("accepted") is True]
  relay_text = ", ".join(accepted_relays) if accepted_relays else "no relay accepted the event"
  if draft_type == "profile":
    status_line = (
      f"The profile update has been signed and published.\n\nRelays: {relay_text}"
      if published_ok
      else "The profile update was signed, but relay publishing did not succeed."
    )
    return (
      f"Approved. {status_line}\n\n"
      f"Event ID: {event.get('id', '')}\n"
      f"Pubkey: {nostr.get('publicKey', '')}"
    )
  status_line = (
    f"The post has been signed and published.\n\nRelays: {relay_text}"
    if published_ok
    else "The post was signed, but relay publishing did not succeed."
  )
  return (
    f"Approved. {status_line}\n\n"
    f"Event ID: {event.get('id', '')}\n"
    f"Pubkey: {nostr.get('publicKey', '')}"
  )


async def generate_nostr_draft(payload: dict, revision_note: str = "", previous_draft: str = "") -> str:
  extra_instruction = build_nostr_draft_instruction(
    payload,
    revision_note=revision_note,
    previous_draft=previous_draft,
  )
  return await generate_reply(payload, extra_instruction=extra_instruction)


def extract_json_object(raw_text: str) -> dict:
  text = normalize_text(raw_text).strip()
  candidates = [text]

  if text.startswith("```"):
    lines = text.splitlines()
    if len(lines) >= 3 and lines[-1].strip() == "```":
      fenced = "\n".join(lines[1:-1]).strip()
      if fenced.lower().startswith("json"):
        fenced = fenced[4:].lstrip()
      candidates.append(fenced)

  start = text.find("{")
  end = text.rfind("}")
  if start != -1 and end != -1 and end > start:
    candidates.append(text[start:end + 1].strip())

  last_exc: Exception | None = None
  for candidate in candidates:
    if not candidate:
      continue
    try:
      payload = json.loads(candidate)
      if isinstance(payload, dict):
        return payload
    except Exception as exc:
      last_exc = exc

  raise HTTPException(status_code=502, detail=f"profile draft is not valid JSON: {last_exc}")


def normalize_profile_json(raw_text: str) -> tuple[str, str]:
  payload = extract_json_object(raw_text)

  allowed_keys = {
    "name",
    "display_name",
    "about",
    "website",
    "picture",
    "banner",
    "nip05",
    "lud16",
  }
  normalized = {}
  for key, value in payload.items():
    if not isinstance(key, str):
      continue
    if value is None:
      continue
    normalized_key = "display_name" if key == "displayName" else key
    if normalized_key not in allowed_keys:
      continue
    if isinstance(value, (str, int, float, bool)):
      normalized[normalized_key] = value

  canonical = json.dumps(normalized, separators=(",", ":"), sort_keys=True)
  pretty = json.dumps(normalized, indent=2, sort_keys=True)
  return canonical, pretty


def normalize_proposal_json(raw_text: str) -> tuple[str, str, str, list[dict]]:
  payload = extract_json_object(raw_text)
  topic_slug = normalize_text(payload.get("topicSlug")).lower()
  summary = normalize_text(payload.get("summary"))
  preview_markdown = normalize_text(payload.get("previewMarkdown"))
  raw_files = payload.get("files")
  if not topic_slug or not summary or not isinstance(raw_files, list) or not raw_files:
    raise HTTPException(status_code=502, detail="proposal draft is missing topicSlug, summary, or files")
  normalized_slug = "".join(ch if ch.isalnum() or ch == "-" else "-" for ch in topic_slug).strip("-")
  while "--" in normalized_slug:
    normalized_slug = normalized_slug.replace("--", "-")
  if not normalized_slug:
    raise HTTPException(status_code=502, detail="proposal topicSlug is empty after normalization")

  normalized_files: list[dict] = []
  for item in raw_files:
    if not isinstance(item, dict):
      continue
    path = normalize_text(item.get("path"))
    content = item.get("content")
    if not path or not isinstance(content, str) or not content.strip():
      continue
    normalized_files.append({
      "path": path,
      "content": content.rstrip() + "\n",
    })

  if not normalized_files:
    raise HTTPException(status_code=502, detail="proposal draft files are empty after normalization")

  if not preview_markdown:
    preview_lines = [
      f"# Proposed file changes: {summary}",
      "",
      "## Files",
    ]
    preview_lines.extend(f"- `{item['path']}`" for item in normalized_files)
    preview_markdown = "\n".join(preview_lines)

  return normalized_slug, summary, preview_markdown, normalized_files


async def generate_nostr_profile(payload: dict, revision_note: str = "", previous_profile: str = "") -> tuple[str, str]:
  extra_instruction = build_nostr_profile_instruction(
    payload,
    revision_note=revision_note,
    previous_profile=previous_profile,
  )
  raw_reply = await generate_reply(payload, extra_instruction=extra_instruction)
  return normalize_profile_json(raw_reply)


async def generate_feedback_proposal(payload: dict, revision_note: str = "", previous_body: str = "") -> tuple[str, str, str, list[dict]]:
  extra_instruction = build_feedback_proposal_instruction(
    payload,
    revision_note=revision_note,
    previous_body=previous_body,
  )
  raw_reply = await generate_reply(payload, extra_instruction=extra_instruction)
  return normalize_proposal_json(raw_reply)


def build_memory_lookup_instruction(query_text: str, results: list[dict]) -> str:
  lines = [
    "Use only the memory retrieval results below to answer the user's memory lookup request.",
    "If the results are sparse, say that directly instead of inventing details.",
    "Keep the answer concise and useful.",
    f"Memory lookup query:\n{query_text}",
    "Retrieved memory results:",
  ]
  for idx, item in enumerate(results, start=1):
    snippet = normalize_text(item.get("snippet"))
    title = normalize_text(item.get("title"))
    context = normalize_text(item.get("context"))
    score = item.get("score")
    lines.append(f"{idx}. title={title!r} score={score!r}")
    if context:
      lines.append(f"   context: {context}")
    if snippet:
      lines.append(f"   snippet: {snippet}")
  return "\n".join(lines)


def build_pending_draft(payload: dict, event_payload: dict, draft_type: str, preview_text: str) -> dict:
  event = payload.get("event") or {}
  sender = event.get("sender") or {}
  return {
    "id": f"{RUNTIME_AGENT_ID}-{int(time.time())}",
    "createdAt": int(time.time()),
    "draftType": draft_type,
    "chatId": event.get("chat", {}).get("id"),
    "replyToMessageId": event.get("messageId"),
    "requestedBy": {
      "id": sender.get("id"),
      "username": sender.get("username"),
      "firstName": sender.get("firstName"),
      "lastName": sender.get("lastName"),
    },
    "event": event_payload,
    "previewText": preview_text,
  }


@app.get("/v1/runtime/status")
async def runtime_status(
  authorization: str | None = Header(default=None),
):
  expected_token = resolve_internal_api_token()
  if authorization != f"Bearer {expected_token}":
    raise HTTPException(status_code=401, detail="invalid runtime authorization")

  marker = resolve_test_secret_marker()
  return {
    "ok": True,
    "runtime": {
      "agentId": RUNTIME_AGENT_ID,
      "displayName": RUNTIME_DISPLAY_NAME,
      "model": RUNTIME_MODEL,
    },
    "secretProbe": {
      "id": OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_ID,
      "resolved": bool(marker),
    },
  }


@app.get("/v1/runtime/nostr/status")
async def runtime_nostr_status(
  authorization: str | None = Header(default=None),
):
  expected_token = resolve_internal_api_token()
  if authorization != f"Bearer {expected_token}":
    raise HTTPException(status_code=401, detail="invalid runtime authorization")

  if not nostr_signer_configured():
    return {
      "ok": True,
      "runtime": {
        "agentId": RUNTIME_AGENT_ID,
        "displayName": RUNTIME_DISPLAY_NAME,
      },
      "nostr": {
        "configured": False,
      },
    }

  signer_status = await request_nostr_signer("GET", "/v1/nostr/status")
  return {
    "ok": True,
    "runtime": {
      "agentId": RUNTIME_AGENT_ID,
      "displayName": RUNTIME_DISPLAY_NAME,
    },
    "nostr": signer_status.get("nostr", {"configured": False}),
  }


@app.get("/v1/runtime/proposals/status")
async def runtime_proposal_status(
  authorization: str | None = Header(default=None),
):
  expected_token = resolve_internal_api_token()
  if authorization != f"Bearer {expected_token}":
    raise HTTPException(status_code=401, detail="invalid runtime authorization")

  return {
    "ok": True,
    "runtime": {
      "agentId": RUNTIME_AGENT_ID,
      "displayName": RUNTIME_DISPLAY_NAME,
    },
    "proposals": {
      "configured": proposal_service_configured(),
      "agentId": RUNTIME_AGENT_ID,
      "enabled": proposal_service_configured(),
    },
  }


@app.get("/v1/runtime/memory/status")
async def runtime_memory_status(
  authorization: str | None = Header(default=None),
):
  expected_token = resolve_internal_api_token()
  if authorization != f"Bearer {expected_token}":
    raise HTTPException(status_code=401, detail="invalid runtime authorization")

  if not memory_service_configured():
    return {
      "ok": True,
      "runtime": {
        "agentId": RUNTIME_AGENT_ID,
        "displayName": RUNTIME_DISPLAY_NAME,
      },
      "memory": {
        "configured": False,
      },
    }

  transport = httpx.AsyncHTTPTransport(uds=OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET)
  async with httpx.AsyncClient(
    transport=transport,
    base_url="http://memory-service",
    timeout=20,
  ) as client:
    response = await client.get(
      "/v1/memory/status",
      headers={"Authorization": f"Bearer {OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN}"},
    )
    response.raise_for_status()
  return {
    "ok": True,
    "runtime": {
      "agentId": RUNTIME_AGENT_ID,
      "displayName": RUNTIME_DISPLAY_NAME,
    },
    "memory": (response.json() or {}).get("memory", {"configured": False}),
  }


@app.post("/v1/runtime/nostr/sign-event")
async def runtime_nostr_sign_event(
  request: Request,
  authorization: str | None = Header(default=None),
):
  expected_token = resolve_internal_api_token()
  if authorization != f"Bearer {expected_token}":
    raise HTTPException(status_code=401, detail="invalid runtime authorization")

  payload = await request.json()
  return await request_nostr_signer("POST", "/v1/nostr/sign-event", payload)


@app.post("/v1/inbound/telegram")
async def inbound_telegram(
  request: Request,
  authorization: str | None = Header(default=None),
):
  expected_token = resolve_internal_api_token()
  if authorization != f"Bearer {expected_token}":
    raise HTTPException(status_code=401, detail="invalid runtime authorization")

  payload = await request.json()
  event = payload.get("event") or {}
  chat = event.get("chat") or {}
  text = event.get("text") or ""
  if not isinstance(text, str) or not text.strip():
    return {"ok": True, "actions": []}

  pending_nostr = load_pending_nostr()
  pending_proposal = load_pending_proposal()
  last_opened_proposal = load_last_opened_proposal()
  if sender_is_operator(event) and pending_nostr:
    if is_approval_command(text):
      draft_type = str(pending_nostr.get("draftType") or "post")
      signed = await request_nostr_signer(
        "POST",
        "/v1/nostr/sign-event",
        {
          "intent": "publish",
          "approval": {
            "approved": True,
            "approvedBy": str((event.get("sender") or {}).get("username") or (event.get("sender") or {}).get("id") or "operator"),
            "approvedAt": str(int(time.time())),
            "notes": "Approved via Telegram reply",
          },
          "event": {
            **(pending_nostr.get("event") or {}),
            "created_at": int(time.time()),
          },
        },
      )
      clear_pending_nostr()
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": signed_ack_message(signed, draft_type=draft_type),
            },
          }
        ],
      }

    if is_reject_command(text):
      clear_pending_nostr()
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": "Draft discarded. Nothing was signed or published.",
            },
          }
        ],
      }

    revision_note = revision_instruction(text)
    if revision_note:
      draft_type = str(pending_nostr.get("draftType") or "post")
      if draft_type == "profile":
        revised_content, revised_preview = await generate_nostr_profile(
          payload,
          revision_note=revision_note,
          previous_profile=str(pending_nostr.get("previewText") or ""),
        )
        pending_nostr["event"] = {
          "kind": 0,
          "tags": [],
          "content": revised_content,
        }
        pending_nostr["previewText"] = revised_preview
      else:
        revised_draft = await generate_nostr_draft(
          payload,
          revision_note=revision_note,
          previous_draft=str((pending_nostr.get("event") or {}).get("content") or ""),
        )
        pending_nostr["event"] = {
          "kind": 1,
          "tags": [],
          "content": revised_draft,
        }
        pending_nostr["previewText"] = revised_draft
      pending_nostr["updatedAt"] = int(time.time())
      save_pending_nostr(pending_nostr)
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": approval_message(
                str(pending_nostr.get("previewText") or ""),
                pending_nostr["id"],
                draft_type=draft_type,
              ),
            },
          }
        ],
      }

  if sender_is_operator(event) and pending_proposal:
    if is_approval_command(text):
      result = await request_proposal_service(
        "POST",
        "/v1/proposals/open",
        {
          "topicSlug": str(pending_proposal.get("topicSlug") or ""),
          "summary": str(pending_proposal.get("summary") or ""),
          "files": pending_proposal.get("files") or [],
        },
      )
      clear_pending_proposal()
      pr_url = (
        (result.get("proposal") or {}).get("prUrl")
        or (result.get("proposal") or {}).get("pullRequestUrl")
        or ""
      ).strip()
      save_last_opened_proposal(
        {
          "id": str(pending_proposal.get("id") or ""),
          "openedAt": int(time.time()),
          "topicSlug": str(pending_proposal.get("topicSlug") or ""),
          "summary": str(pending_proposal.get("summary") or ""),
          "prUrl": pr_url,
        }
      )
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": (
                f"Approved. Proposal PR opened successfully.\n\n{pr_url}"
                if pr_url else "Approved. Proposal PR opened successfully."
              ),
            },
          }
        ],
      }

    if is_reject_command(text):
      clear_pending_proposal()
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": "Proposal discarded. No branch or PR was created.",
            },
          }
        ],
      }

    revision_note = revision_instruction(text)
    if revision_note:
      topic_slug, summary, preview_markdown, files = await generate_feedback_proposal(
        payload,
        revision_note=revision_note,
        previous_body=str(pending_proposal.get("previewMarkdown") or ""),
      )
      pending_proposal.update(
        {
          "topicSlug": topic_slug,
          "summary": summary,
          "previewMarkdown": preview_markdown,
          "files": files,
          "updatedAt": int(time.time()),
        }
      )
      save_pending_proposal(pending_proposal)
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": (
                f"Proposal draft ready for approval ({pending_proposal['id']}).\n\n"
                f"{preview_markdown}\n\n"
                "Reply `approve` to open a PR. Reply `reject` to discard it. "
                "Reply `revise: <changes>` to request a revision."
              ),
            },
          }
      ],
    }

  if sender_is_operator(event) and memory_service_configured() and looks_like_observation_memory_request(text):
    observation_content = normalize_observation_memory_content(text)
    observation_result = await request_memory_observation_create(observation_content)
    observation = observation_result.get("observation") or {}
    observation_id = str(observation.get("id") or "").strip()
    return {
      "ok": True,
      "actions": [
        {
          "type": "telegram.sendMessage",
          "target": {
            "chatId": chat.get("id"),
            "replyToMessageId": event.get("messageId"),
          },
          "message": {
            "text": (
              f"Stored observation candidate {observation_id} for review."
              if observation_id else "Stored observation candidate for review."
            ),
          },
        }
      ],
    }

  if memory_service_configured() and looks_like_memory_lookup_request(text):
    memory_query = normalize_memory_lookup_query(text)
    memory_result = await request_memory_service(memory_query)
    results = ((memory_result.get("memory") or {}).get("results") or [])
    if not results:
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": "I checked my memory and did not find a relevant stored result for that query.",
            },
          }
        ],
      }
    reply_text = await generate_reply(
      payload,
      extra_instruction=build_memory_lookup_instruction(memory_query, results),
    )
    return {
      "ok": True,
      "actions": [
        {
          "type": "telegram.sendMessage",
          "target": {
            "chatId": chat.get("id"),
            "replyToMessageId": event.get("messageId"),
          },
          "message": {
            "text": reply_text,
          },
        }
      ],
    }

  if proposal_service_configured() and looks_like_feedback_proposal_request(text):
    topic_slug, summary, preview_markdown, files = await generate_feedback_proposal(payload)
    if (
      last_opened_proposal
      and str(last_opened_proposal.get("topicSlug") or "") == topic_slug
      and str(last_opened_proposal.get("summary") or "") == summary
      and int(last_opened_proposal.get("openedAt") or 0) >= int(time.time()) - 1800
    ):
      existing_pr_url = str(last_opened_proposal.get("prUrl") or "").strip()
      return {
        "ok": True,
        "actions": [
          {
            "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": (
                f"That proposal was already opened.\n\n{existing_pr_url}"
                if existing_pr_url else "That proposal was already opened."
              ),
            },
          }
        ],
      }
    pending_proposal = {
      "id": f"{RUNTIME_AGENT_ID}-proposal-{int(time.time())}",
      "createdAt": int(time.time()),
      "topicSlug": topic_slug,
      "summary": summary,
      "previewMarkdown": preview_markdown,
      "files": files,
    }
    save_pending_proposal(pending_proposal)
    return {
      "ok": True,
      "actions": [
        {
          "type": "telegram.sendMessage",
          "target": {
            "chatId": chat.get("id"),
            "replyToMessageId": event.get("messageId"),
          },
          "message": {
            "text": (
              f"Proposal draft ready for approval ({pending_proposal['id']}).\n\n"
              f"{preview_markdown}\n\n"
              "Reply `approve` to open a PR. Reply `reject` to discard it. "
              "Reply `revise: <changes>` to request a revision."
            ),
          },
        }
      ],
    }

  if nostr_signer_configured() and looks_like_nostr_profile_request(text):
    profile_content, profile_preview = await generate_nostr_profile(payload)
    pending_nostr = build_pending_draft(
      payload,
      {
        "kind": 0,
        "tags": [],
        "content": profile_content,
      },
      "profile",
      profile_preview,
    )
    save_pending_nostr(pending_nostr)
    return {
      "ok": True,
      "actions": [
        {
          "type": "telegram.sendMessage",
          "target": {
            "chatId": chat.get("id"),
            "replyToMessageId": event.get("messageId"),
          },
          "message": {
            "text": approval_message(profile_preview, pending_nostr["id"], draft_type="profile"),
          },
        }
      ],
    }

  if nostr_signer_configured() and looks_like_nostr_publish_request(text):
    draft_text = await generate_nostr_draft(payload)
    if not draft_text:
      return {"ok": True, "actions": []}
    pending_nostr = build_pending_draft(
      payload,
      {
        "kind": 1,
        "tags": [],
        "content": draft_text,
      },
      "post",
      draft_text,
    )
    save_pending_nostr(pending_nostr)
    return {
      "ok": True,
      "actions": [
        {
          "type": "telegram.sendMessage",
            "target": {
              "chatId": chat.get("id"),
              "replyToMessageId": event.get("messageId"),
            },
            "message": {
              "text": approval_message(draft_text, pending_nostr["id"], draft_type="post"),
            },
          }
        ],
      }

  reply_text = await generate_reply(payload)
  if not reply_text:
    return {"ok": True, "actions": []}

  return {
    "ok": True,
    "actions": [
      {
        "type": "telegram.sendMessage",
        "target": {
          "chatId": chat.get("id"),
          "replyToMessageId": event.get("messageId"),
        },
        "message": {
          "text": reply_text,
        },
      }
    ],
  }
PY
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "${runtime_dir}/app.py"
  chmod 640 "${runtime_dir}/app.py"
}

write_private_runtime_containerfile() {
  cat >"$OPENCLAW_PRIVATE_RUNTIME_CONTAINERFILE" <<'EOF'
FROM docker.io/library/python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN pip install --no-cache-dir fastapi httpx uvicorn

WORKDIR /app

CMD ["sh", "-lc", "exec uvicorn app:app --host ${OPENCLAW_PRIVATE_RUNTIME_HOST:-127.0.0.1} --port ${OPENCLAW_PRIVATE_RUNTIME_PORT}"]
EOF
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_PRIVATE_RUNTIME_CONTAINERFILE"
  chmod 640 "$OPENCLAW_PRIVATE_RUNTIME_CONTAINERFILE"
}

build_private_runtime_image() {
  write_private_runtime_containerfile
  run_as_openclaw podman build -t "$OPENCLAW_PRIVATE_RUNTIME_IMAGE" -f "$OPENCLAW_PRIVATE_RUNTIME_CONTAINERFILE" "$OPENCLAW_PRIVATE_RUNTIME_BASE_DIR"
}

read_agent_internal_api_token() {
  read_agent_secret_value "$1" internal apiToken
}

read_agent_secret_value() {
  local agent_id="$1"
  local section="$2"
  local key="$3"
  local secret_store="$OPENCLAW_ROOT_SECRETS_DIR/${agent_id}.json"
  python3 - "$secret_store" "$section" "$key" <<'PY'
import json
import sys
from pathlib import Path

store = Path(sys.argv[1])
section = sys.argv[2]
key = sys.argv[3]
payload = json.loads(store.read_text(encoding="utf-8"))
value = (((payload.get(section) or {}).get(key)) if isinstance(payload, dict) else None)
if not isinstance(value, str) or not value.strip():
    raise SystemExit(1)
print(value)
PY
}

private_proposal_enabled() {
  local public_id="$1"
  local enabled_id
  for enabled_id in "${OPENCLAW_PROPOSAL_PUBLIC_IDS[@]}"; do
    if [[ "$enabled_id" == "$public_id" ]]; then
      return 0
    fi
  done
  return 1
}

private_proposal_service_name() {
  printf 'clawbot-%s-proposal.service\n' "$1"
}

private_proposal_dir() {
  printf '%s/%s\n' "$OPENCLAW_ROOT_STATE_DIR/proposal-services" "$1"
}

private_proposal_socket_dir() {
  printf '%s/%s/proposal-service\n' "$OPENCLAW_PROPOSAL_SOCKET_BASE_DIR" "$1"
}

private_proposal_socket_path() {
  printf '%s/service.sock\n' "$(private_proposal_socket_dir "$1")"
}

private_proposal_repo_branch() {
  printf '%s\n' "${OPENCLAW_AGENT_PROPOSAL_BASE_BRANCH:-main}"
}

private_proposal_unit_name() {
  printf 'clawbot-%s-proposal.service\n' "$1"
}

private_memory_enabled() {
  local public_id="$1"
  local enabled_id
  for enabled_id in "${OPENCLAW_MEMORY_PUBLIC_IDS[@]}"; do
    if [[ "$enabled_id" == "$public_id" ]]; then
      return 0
    fi
  done
  return 1
}

private_memory_dir() {
  printf '%s/%s\n' "$OPENCLAW_ROOT_STATE_DIR/memory-services" "$1"
}

private_memory_socket_dir() {
  printf '%s/%s/memory-service\n' "$OPENCLAW_MEMORY_SOCKET_BASE_DIR" "$1"
}

private_memory_socket_path() {
  printf '%s/service.sock\n' "$(private_memory_socket_dir "$1")"
}

private_memory_unit_name() {
  printf 'clawbot-%s-memory.service\n' "$1"
}

install_agent_proposal_helper() {
  cat >"$OPENCLAW_AGENT_PROPOSAL_HELPER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
usage: clawbot-agents-pr.sh <agent-id> <topic-slug> <repo-path> [summary]

Creates a branch and pull request in the private clawbot-agents repo using the
configured GitHub App credentials.

Arguments:
  agent-id     Internal agent id, e.g. podcast_media
  topic-slug   Short branch/PR slug, e.g. social-tone
  repo-path    Local path to a clawbot-agents working tree with changes ready
  summary      Optional PR summary; defaults to topic-slug with dashes replaced
               by spaces

Environment overrides:
  CLAWBOT_AGENTS_APP_ID_FILE
  CLAWBOT_AGENTS_INSTALLATION_ID_FILE
  CLAWBOT_AGENTS_APP_KEY_FILE
  CLAWBOT_AGENTS_BASE_BRANCH
USAGE
  exit 1
}

[ "$#" -ge 3 ] || usage

agent_id="$1"
topic_slug="$2"
repo_path="$3"
summary="${4:-${topic_slug//-/ }}"

app_id_file="${CLAWBOT_AGENTS_APP_ID_FILE:-/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.app_id}"
installation_id_file="${CLAWBOT_AGENTS_INSTALLATION_ID_FILE:-/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.installation_id}"
app_key_file="${CLAWBOT_AGENTS_APP_KEY_FILE:-/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.pem}"
base_branch="${CLAWBOT_AGENTS_BASE_BRANCH:-main}"

for path in "$app_id_file" "$installation_id_file" "$app_key_file"; do
  [ -r "$path" ] || { echo "missing required credential file: $path" >&2; exit 1; }
done

[ -d "$repo_path/.git" ] || { echo "repo path is not a git working tree: $repo_path" >&2; exit 1; }

safe_git() {
  git -C "$repo_path" -c "safe.directory=$repo_path" "$@"
}

app_id="$(tr -d '[:space:]' < "$app_id_file")"
installation_id="$(tr -d '[:space:]' < "$installation_id_file")"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

create_jwt() {
  local now exp header payload header_b64 payload_b64 signing_input sig
  now="$(date +%s)"
  exp="$((now + 540))"
  header='{"alg":"RS256","typ":"JWT"}'
  payload="$(printf '{"iat":%s,"exp":%s,"iss":"%s"}' "$now" "$exp" "$app_id")"
  header_b64="$(printf '%s' "$header" | base64url)"
  payload_b64="$(printf '%s' "$payload" | base64url)"
  signing_input="${header_b64}.${payload_b64}"
  sig="$(
    printf '%s' "$signing_input" \
      | openssl dgst -binary -sha256 -sign "$app_key_file" \
      | base64url
  )"
  printf '%s.%s' "$signing_input" "$sig"
}

app_jwt="$(create_jwt)"

installation_token="$(
  curl -fsSL \
    -X POST \
    -H "Authorization: Bearer ${app_jwt}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/app/installations/${installation_id}/access_tokens" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])'
)"

remote_url="$(safe_git remote get-url origin)"
owner_repo="$(
  python3 - "$remote_url" <<'PY'
import re, sys
url = sys.argv[1]
patterns = [
    r'github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\.git)?$',
]
for pattern in patterns:
    m = re.search(pattern, url)
    if m:
        print(f'{m.group("owner")}/{m.group("repo")}')
        sys.exit(0)
raise SystemExit(f"could not parse GitHub owner/repo from remote URL: {url}")
PY
)"

owner="${owner_repo%/*}"
repo="${owner_repo#*/}"
https_remote_url="https://x-access-token:${installation_token}@github.com/${owner_repo}.git"

timestamp="$(date +%Y%m%d-%H%M%S)"
branch="agent/${agent_id}/${topic_slug}-${timestamp}"
commit_message="agent(${agent_id}): ${summary}"
pr_title="${agent_id}: ${summary}"

safe_git fetch "$https_remote_url" "$base_branch"
safe_git checkout -B "$branch" FETCH_HEAD

if [ -z "$(safe_git status --short)" ]; then
  echo "no changes present in $repo_path" >&2
  exit 1
fi

safe_git add -A
git -C "$repo_path" -c "safe.directory=$repo_path" -c user.name='clawbot-agents-pr-bot[bot]' -c user.email='clawbot-agents-pr-bot[bot]@users.noreply.github.com' commit -m "$commit_message"

safe_git push "$https_remote_url" "$branch"

pr_body_file="$(mktemp)"
cat > "$pr_body_file" <<PRBODY
## Reason

Agent-authored proposal for \`${agent_id}\`.

## Observed behavior

- See commit diff

## Files changed

- See commit diff

## Expected outcome

- Improves \`${agent_id}\` behavior without directly mutating protected \`${base_branch}\`

## Risks

- Prompt drift or overcorrection if merged without review
PRBODY

pr_url="$(
  curl -fsSL \
    -X POST \
    -H "Authorization: Bearer ${installation_token}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${owner}/${repo}/pulls" \
    -d @- <<PRJSON
{
  "title": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$pr_title"),
  "head": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$branch"),
  "base": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$base_branch"),
  "body": $(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1]).read()))' "$pr_body_file")
}
PRJSON
)"

rm -f "$pr_body_file"

printf '%s\n' "$pr_url" | python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])'
EOF
  chown root:root "$OPENCLAW_AGENT_PROPOSAL_HELPER"
  chmod 0700 "$OPENCLAW_AGENT_PROPOSAL_HELPER"
}

prepare_agent_proposal_repo() {
  local repo_dir="$OPENCLAW_AGENT_PROPOSAL_REPO_DIR"
  local legacy_repo_dir="$OPENCLAW_AGENT_PROPOSAL_REPO_DIR_LEGACY"
  local repo_parent
  local clone_url="$OPENCLAW_AGENT_PACK_REPO_URL"
  local branch
  local -a git_prefix=()

  if [[ -z "$clone_url" ]]; then
    echo "OPENCLAW_AGENT_PACK_REPO_URL must be set to prepare proposal repo" >&2
    return 1
  fi

  repo_parent="$(dirname "$repo_dir")"
  branch="$(private_proposal_repo_branch)"
  install -d -m 0750 -o "$OPENCLAW_USER" -g "$OPENCLAW_USER" "$repo_parent"

  if [[ -d "$legacy_repo_dir/.git" && ! -e "$repo_dir" ]]; then
    mv "$legacy_repo_dir" "$repo_dir"
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$repo_dir"
  fi

  if [[ "$clone_url" == git@* || "$clone_url" == ssh://* ]]; then
    if [[ ! -f "$OPENCLAW_AGENT_PACK_SSH_KEY_FILE" ]]; then
      echo "Proposal repo clone requires deploy key at $OPENCLAW_AGENT_PACK_SSH_KEY_FILE" >&2
      return 1
    fi
    chmod 600 "$OPENCLAW_AGENT_PACK_SSH_KEY_FILE"
    git_prefix=(
      env
      "GIT_SSH_COMMAND=ssh -i $OPENCLAW_AGENT_PACK_SSH_KEY_FILE -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
    )
  fi

  if [[ ! -d "$repo_dir/.git" ]]; then
    rm -rf "$repo_dir"
    "${git_prefix[@]}" git clone --branch "$branch" "$clone_url" "$repo_dir"
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$repo_dir"
  fi

  git config --global --add safe.directory "$repo_dir" >/dev/null 2>&1 || true
}

prepare_proposal_service_directories() {
  local public_id
  local proposal_dir
  local socket_dir

  mkdir -p "$OPENCLAW_ROOT_STATE_DIR/proposal-services"
  chown root:root "$OPENCLAW_ROOT_STATE_DIR/proposal-services"
  chmod 700 "$OPENCLAW_ROOT_STATE_DIR/proposal-services"
  mkdir -p "$OPENCLAW_PROPOSAL_SOCKET_BASE_DIR"
  chown root:"$OPENCLAW_USER" "$OPENCLAW_PROPOSAL_SOCKET_BASE_DIR"
  chmod 750 "$OPENCLAW_PROPOSAL_SOCKET_BASE_DIR"

  for public_id in "${OPENCLAW_PROPOSAL_PUBLIC_IDS[@]}"; do
    proposal_dir="$(private_proposal_dir "$public_id")"
    socket_dir="$(private_proposal_socket_dir "$public_id")"
    mkdir -p "$proposal_dir" "$socket_dir"
    chown -R root:root "$proposal_dir"
    chmod 700 "$proposal_dir"
    chown root:"$OPENCLAW_USER" "$socket_dir"
    chmod 750 "$socket_dir"
  done
}

prepare_memory_service_directories() {
  local public_id
  local memory_dir
  local socket_dir

  mkdir -p "$OPENCLAW_ROOT_STATE_DIR/memory-services"
  chown root:root "$OPENCLAW_ROOT_STATE_DIR/memory-services"
  chmod 700 "$OPENCLAW_ROOT_STATE_DIR/memory-services"
  mkdir -p "$OPENCLAW_MEMORY_SOCKET_BASE_DIR"
  chown root:"$OPENCLAW_USER" "$OPENCLAW_MEMORY_SOCKET_BASE_DIR"
  chmod 750 "$OPENCLAW_MEMORY_SOCKET_BASE_DIR"

  for public_id in "${OPENCLAW_MEMORY_PUBLIC_IDS[@]}"; do
    memory_dir="$(private_memory_dir "$public_id")"
    socket_dir="$(private_memory_socket_dir "$public_id")"
    mkdir -p "$memory_dir" "$socket_dir"
    chown -R root:root "$memory_dir"
    chmod 700 "$memory_dir"
    chown root:"$OPENCLAW_USER" "$socket_dir"
    chmod 750 "$socket_dir"
  done
}

render_memory_service_app() {
  local memory_dir="$1"
  cat >"${memory_dir}/app.py" <<'PY'
import json
import os
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException, Request

app = FastAPI()

TENANT_ID = os.getenv("OPENCLAW_PRIVATE_MEMORY_TENANT_ID", "tenant_0").strip()
RUNTIME_PUBLIC_ID = os.getenv("OPENCLAW_PRIVATE_MEMORY_PUBLIC_ID", "stacks").strip()
RUNTIME_DISPLAY_NAME = os.getenv("OPENCLAW_PRIVATE_MEMORY_DISPLAY_NAME", "Stacks").strip()
OPENCLAW_PRIVATE_MEMORY_TOKEN = os.getenv("OPENCLAW_PRIVATE_MEMORY_TOKEN", "").strip()
OPENCLAW_PRIVATE_MEMORY_WRAPPER = os.getenv("OPENCLAW_PRIVATE_MEMORY_WRAPPER", "/usr/local/bin/clawbot-qmd-tenant").strip()
OPENCLAW_PRIVATE_MEMORY_OBSERVATIONS_ROOT = os.getenv("OPENCLAW_PRIVATE_MEMORY_OBSERVATIONS_ROOT", "/opt/clawbot/tenants/tenant_0/memory/observations").strip()


def verify_memory_token(authorization: str | None) -> None:
  if not OPENCLAW_PRIVATE_MEMORY_TOKEN:
    raise HTTPException(status_code=500, detail=f"memory token missing for {RUNTIME_DISPLAY_NAME}")
  if authorization != f"Bearer {OPENCLAW_PRIVATE_MEMORY_TOKEN}":
    raise HTTPException(status_code=401, detail="invalid memory authorization")


def wrapper_json(*args: str) -> dict:
  try:
    result = subprocess.run(
      [OPENCLAW_PRIVATE_MEMORY_WRAPPER, *args],
      check=True,
      capture_output=True,
      text=True,
    )
  except subprocess.CalledProcessError as exc:
    detail = exc.stderr.strip() or exc.stdout.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"memory wrapper failed: {detail}") from exc

  try:
    payload = json.loads(result.stdout)
  except json.JSONDecodeError as exc:
    raise HTTPException(status_code=502, detail=f"invalid memory wrapper response: {exc}") from exc
  if not isinstance(payload, dict):
    raise HTTPException(status_code=502, detail="memory wrapper returned non-object payload")
  return payload


def slugify(value: str) -> str:
  lowered = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
  return lowered[:48] or "observation"


def observation_scope_dir() -> Path:
  return Path(OPENCLAW_PRIVATE_MEMORY_OBSERVATIONS_ROOT) / "bots" / RUNTIME_PUBLIC_ID


def write_observation_entry(content: str) -> dict:
  body = str(content or "").strip()
  if not body:
    raise HTTPException(status_code=400, detail="observation content is required")

  now = datetime.now(timezone.utc)
  timestamp = now.strftime("%Y%m%d-%H%M%S")
  slug = slugify(body)
  observation_id = f"obs-{RUNTIME_PUBLIC_ID}-{slug}-{timestamp}"
  target_dir = observation_scope_dir()
  target_dir.mkdir(parents=True, exist_ok=True)
  target_path = target_dir / f"{observation_id}.md"
  iso_now = now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
  target_path.write_text(
    "\n".join(
      [
        "---",
        f"id: {observation_id}",
        f"tenant_id: {TENANT_ID}",
        f"scope: tenant/{TENANT_ID}/bot/{RUNTIME_PUBLIC_ID}",
        f"bot_id: {RUNTIME_PUBLIC_ID}",
        "type: observation",
        "status: pending_review",
        "visibility: bot",
        "source: explicit_operator_request",
        "confidence: high",
        "tags:",
        "  - observation",
        "  - candidate-memory",
        f"created_at: {iso_now}",
        f"updated_at: {iso_now}",
        "---",
        "",
        body,
        "",
      ]
    ),
    encoding="utf-8",
  )
  return {
    "id": observation_id,
    "path": str(target_path),
    "scope": f"tenant/{TENANT_ID}/bot/{RUNTIME_PUBLIC_ID}",
    "status": "pending_review",
  }


@app.get("/v1/memory/status")
async def memory_status(
  authorization: str | None = Header(default=None),
):
  verify_memory_token(authorization)
  payload = wrapper_json("status", TENANT_ID)
  return {
    "ok": True,
    "memory": {
      "configured": True,
      "tenantId": TENANT_ID,
      "botId": RUNTIME_PUBLIC_ID,
      "wrapper": OPENCLAW_PRIVATE_MEMORY_WRAPPER,
      "status": payload,
    },
  }


@app.post("/v1/memory/query")
async def memory_query(
  request: Request,
  authorization: str | None = Header(default=None),
):
  verify_memory_token(authorization)
  payload = await request.json()
  query = str(payload.get("query") or "").strip()
  if not query:
    raise HTTPException(status_code=400, detail="query is required")
  result = wrapper_json("query", TENANT_ID, RUNTIME_PUBLIC_ID, query)
  return {
    "ok": True,
    "memory": {
      "tenantId": TENANT_ID,
      "botId": RUNTIME_PUBLIC_ID,
      "query": query,
      "results": result.get("results") or [],
      "allowedCollections": result.get("allowedCollections") or [],
    },
  }


@app.post("/v1/memory/observations")
async def memory_observations_create(
  request: Request,
  authorization: str | None = Header(default=None),
):
  verify_memory_token(authorization)
  payload = await request.json()
  content = str(payload.get("content") or "").strip()
  observation = write_observation_entry(content)
  return {
    "ok": True,
    "observation": observation,
  }
PY
  chown root:root "${memory_dir}/app.py"
  chmod 700 "${memory_dir}/app.py"
}

ensure_memory_service_venv() {
  local memory_venv="$OPENCLAW_ROOT_STATE_DIR/memory-services/.venv"
  if [[ ! -x "${memory_venv}/bin/python" ]]; then
    python3 -m venv "$memory_venv"
  fi
  if [[ ! -x "${memory_venv}/bin/pip" ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3-venv \
      python3-pip \
      python3-setuptools
    rm -rf "$memory_venv"
    python3 -m venv "$memory_venv"
  fi
  "${memory_venv}/bin/pip" install --upgrade --no-cache-dir fastapi uvicorn >/tmp/openclaw-memory-service-pip.log 2>&1
}

write_memory_service_unit() {
  local public_id="$1"
  local display_name="$2"
  local memory_unit="/etc/systemd/system/$(private_memory_unit_name "$public_id")"
  local memory_dir
  local memory_socket_dir
  local memory_socket_path
  local memory_token
  memory_dir="$(private_memory_dir "$public_id")"
  memory_socket_dir="$(private_memory_socket_dir "$public_id")"
  memory_socket_path="$(private_memory_socket_path "$public_id")"
  memory_token="$(read_agent_internal_api_token "$(private_runtime_agent_id "$public_id")")"
  cat >"$memory_unit" <<EOF
[Unit]
Description=Clawbot ${display_name} memory service
After=network.target

[Service]
Type=simple
User=root
Group=$OPENCLAW_USER
UMask=0007
WorkingDirectory=$memory_dir
ExecStartPre=/usr/bin/install -d -o root -g $OPENCLAW_USER -m 0750 $memory_socket_dir
ExecStartPre=/usr/bin/rm -f $memory_socket_path
ExecStart=$OPENCLAW_ROOT_STATE_DIR/memory-services/.venv/bin/uvicorn app:app --uds $memory_socket_path
Environment=OPENCLAW_PRIVATE_MEMORY_TENANT_ID=$OPENCLAW_TENANT_ID
Environment=OPENCLAW_PRIVATE_MEMORY_PUBLIC_ID=$public_id
Environment=OPENCLAW_PRIVATE_MEMORY_DISPLAY_NAME=$display_name
Environment=OPENCLAW_PRIVATE_MEMORY_TOKEN=$memory_token
Environment=OPENCLAW_PRIVATE_MEMORY_WRAPPER=$OPENCLAW_QMD_WRAPPER
Environment=OPENCLAW_PRIVATE_MEMORY_OBSERVATIONS_ROOT=$OPENCLAW_TENANT_OBSERVATION_MEMORY_DIR
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  chown root:root "$memory_unit"
  chmod 0644 "$memory_unit"
}

configure_memory_services() {
  local public_id
  local display_name
  local memory_dir
  local memory_unit

  if [[ "${#OPENCLAW_MEMORY_PUBLIC_IDS[@]}" -eq 0 ]]; then
    return 0
  fi

  prepare_memory_service_directories
  ensure_memory_service_venv

  for public_id in "${OPENCLAW_MEMORY_PUBLIC_IDS[@]}"; do
    display_name="$(private_runtime_display_name "$public_id")"
    memory_dir="$(private_memory_dir "$public_id")"
    render_memory_service_app "$memory_dir"
    write_memory_service_unit "$public_id" "$display_name"
  done

  run_step "Reload systemd for memory services" systemctl daemon-reload

  for public_id in "${OPENCLAW_MEMORY_PUBLIC_IDS[@]}"; do
    memory_unit="$(private_memory_unit_name "$public_id")"
    run_step "Enable ${public_id} memory service" systemctl enable "$memory_unit"
    run_step "Restart ${public_id} memory service" systemctl restart "$memory_unit"
  done
}

render_proposal_service_app() {
  local proposal_dir="$1"
  cat >"${proposal_dir}/app.py" <<'PY'
import base64
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException, Request

app = FastAPI()

RUNTIME_AGENT_ID = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_AGENT_ID", "podcast_media").strip()
RUNTIME_DISPLAY_NAME = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_DISPLAY_NAME", "Stacks").strip()
OPENCLAW_PRIVATE_PROPOSAL_TOKEN = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_TOKEN", "").strip()
OPENCLAW_PRIVATE_PROPOSAL_REPO_DIR = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_REPO_DIR", "/opt/clawbot/repos/clawbot-agents").strip()
OPENCLAW_PRIVATE_PROPOSAL_HELPER = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_HELPER", "/usr/local/bin/clawbot-agents-pr").strip()
OPENCLAW_PRIVATE_PROPOSAL_BASE_BRANCH = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_BASE_BRANCH", "main").strip()
OPENCLAW_PRIVATE_PROPOSAL_APP_ID_FILE = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_APP_ID_FILE", "/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.app_id").strip()
OPENCLAW_PRIVATE_PROPOSAL_INSTALLATION_ID_FILE = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_INSTALLATION_ID_FILE", "/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.installation_id").strip()
OPENCLAW_PRIVATE_PROPOSAL_APP_KEY_FILE = os.getenv("OPENCLAW_PRIVATE_PROPOSAL_APP_KEY_FILE", "/opt/clawbot-root/bootstrap/clawbot-agents-pr-bot.pem").strip()

TOPIC_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


def verify_proposal_token(authorization: str | None) -> None:
  if not OPENCLAW_PRIVATE_PROPOSAL_TOKEN:
    raise HTTPException(status_code=500, detail=f"proposal token missing for {RUNTIME_DISPLAY_NAME}")
  if authorization != f"Bearer {OPENCLAW_PRIVATE_PROPOSAL_TOKEN}":
    raise HTTPException(status_code=401, detail="invalid proposal authorization")


def normalize_payload(payload: dict) -> dict:
  topic_slug = str(payload.get("topicSlug") or "").strip().lower()
  summary = str(payload.get("summary") or "").strip()
  files = payload.get("files")

  if not TOPIC_RE.fullmatch(topic_slug):
    raise HTTPException(status_code=400, detail="topicSlug must be lowercase kebab-case")
  if not summary:
    raise HTTPException(status_code=400, detail="summary is required")
  if not isinstance(files, list) or not files:
    raise HTTPException(status_code=400, detail="files is required")

  normalized_files = []
  allowed_prefix = f"agents/{RUNTIME_AGENT_ID}/"
  for item in files:
    if not isinstance(item, dict):
      continue
    path = str(item.get("path") or "").strip()
    content = item.get("content")
    if not path or not isinstance(content, str):
      continue
    if ".." in path.split("/"):
      raise HTTPException(status_code=400, detail="proposal file paths may not contain parent traversal")
    if not path.startswith(allowed_prefix):
      raise HTTPException(status_code=400, detail=f"proposal file path must stay under {allowed_prefix}")
    if not path.endswith(".md"):
      raise HTTPException(status_code=400, detail="proposal file path must target a markdown file")
    normalized_files.append({
      "path": path,
      "content": content.rstrip() + "\n",
    })

  if not normalized_files:
    raise HTTPException(status_code=400, detail="proposal files are empty after normalization")

  return {
    "topicSlug": topic_slug,
    "summary": summary,
    "files": normalized_files,
  }


def parse_github_owner_repo(remote_url: str) -> tuple[str, str]:
  patterns = [
    r"github\.com[:/](?P<owner>[^/]+)/(?P<repo>[^/.]+)(?:\.git)?$",
  ]
  for pattern in patterns:
    match = re.search(pattern, remote_url)
    if match:
      return match.group("owner"), match.group("repo")
  raise HTTPException(status_code=500, detail=f"unable to parse GitHub owner/repo from remote: {remote_url}")


def github_app_installation_token() -> str:
  try:
    app_id = Path(OPENCLAW_PRIVATE_PROPOSAL_APP_ID_FILE).read_text(encoding="utf-8").strip()
    installation_id = Path(OPENCLAW_PRIVATE_PROPOSAL_INSTALLATION_ID_FILE).read_text(encoding="utf-8").strip()
  except OSError as exc:
    raise HTTPException(status_code=500, detail=f"unable to read GitHub App credential files: {exc}") from exc

  now = int(time.time())
  header = {"alg": "RS256", "typ": "JWT"}
  payload = {"iat": now, "exp": now + 540, "iss": app_id}

  def b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")

  signing_input = f"{b64url(json.dumps(header, separators=(',', ':')).encode())}.{b64url(json.dumps(payload, separators=(',', ':')).encode())}"
  try:
    signature = subprocess.run(
      ["openssl", "dgst", "-binary", "-sha256", "-sign", OPENCLAW_PRIVATE_PROPOSAL_APP_KEY_FILE],
      input=signing_input.encode(),
      check=True,
      capture_output=True,
    ).stdout
  except subprocess.CalledProcessError as exc:
    detail = exc.stderr.decode().strip() or str(exc)
    raise HTTPException(status_code=500, detail=f"unable to sign GitHub App JWT: {detail}") from exc

  jwt_value = f"{signing_input}.{b64url(signature)}"
  try:
    response = subprocess.run(
      [
        "curl",
        "-fsSL",
        "-X",
        "POST",
        "-H",
        f"Authorization: Bearer {jwt_value}",
        "-H",
        "Accept: application/vnd.github+json",
        f"https://api.github.com/app/installations/{installation_id}/access_tokens",
      ],
      check=True,
      capture_output=True,
      text=True,
    )
    token = json.loads(response.stdout)["token"]
  except (subprocess.CalledProcessError, KeyError, json.JSONDecodeError) as exc:
    detail = getattr(exc, "stderr", "") or getattr(exc, "stdout", "") or str(exc)
    raise HTTPException(status_code=500, detail=f"unable to mint GitHub installation token: {detail}") from exc
  return str(token).strip()


def prepare_proposal_workspace(source_repo_dir: Path) -> Path:
  workspace_root = Path(tempfile.mkdtemp(prefix="clawbot-agents-pr-", dir="/tmp"))
  workspace_dir = workspace_root / "repo"
  try:
    source_remote = subprocess.run(
      [
        "git",
        "-c",
        f"safe.directory={source_repo_dir}",
        "-C",
        str(source_repo_dir),
        "remote",
        "get-url",
        "origin",
      ],
      check=True,
      capture_output=True,
      text=True,
    ).stdout.strip()
    owner, repo = parse_github_owner_repo(source_remote)
    installation_token = github_app_installation_token()
    https_remote = f"https://x-access-token:{installation_token}@github.com/{owner}/{repo}.git"
    subprocess.run(
      [
        "git",
        "clone",
        "--branch",
        OPENCLAW_PRIVATE_PROPOSAL_BASE_BRANCH or "main",
        https_remote,
        str(workspace_dir),
      ],
      check=True,
      capture_output=True,
      text=True,
    )
    subprocess.run(
      ["git", "-C", str(workspace_dir), "remote", "set-url", "origin", source_remote],
      check=True,
      capture_output=True,
      text=True,
    )
  except subprocess.CalledProcessError as exc:
    detail = exc.stderr.strip() or exc.stdout.strip() or str(exc)
    raise HTTPException(status_code=500, detail=f"unable to prepare proposal workspace: {detail}") from exc
  return workspace_dir


def apply_proposal_files(repo_dir: Path, payload: dict) -> list[str]:
  changed_paths: list[str] = []
  for item in payload["files"]:
    target = repo_dir / item["path"]
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(item["content"], encoding="utf-8")
    changed_paths.append(item["path"])
  return changed_paths


def rerender_agent_config(repo_dir: Path) -> None:
  render_script = repo_dir / "scripts" / "render-agent-config.sh"
  if not render_script.exists():
    raise HTTPException(status_code=500, detail=f"render script missing: {render_script}")
  try:
    subprocess.run(
      ["bash", str(render_script)],
      cwd=repo_dir,
      check=True,
      capture_output=True,
      text=True,
    )
  except subprocess.CalledProcessError as exc:
    detail = exc.stderr.strip() or exc.stdout.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"render-agent-config failed: {detail}") from exc


def open_proposal_pr(payload: dict, repo_dir: Path) -> str:
  helper_path = Path(OPENCLAW_PRIVATE_PROPOSAL_HELPER)
  if not helper_path.exists():
    raise HTTPException(status_code=500, detail=f"proposal helper not installed: {helper_path}")

  env = os.environ.copy()
  env["CLAWBOT_AGENTS_BASE_BRANCH"] = OPENCLAW_PRIVATE_PROPOSAL_BASE_BRANCH or "main"
  try:
    result = subprocess.run(
      [
        str(helper_path),
        RUNTIME_AGENT_ID,
        payload["topicSlug"],
        str(repo_dir),
        payload["summary"],
      ],
      check=True,
      capture_output=True,
      text=True,
      env=env,
    )
  except subprocess.CalledProcessError as exc:
    detail = exc.stderr.strip() or exc.stdout.strip() or str(exc)
    raise HTTPException(status_code=502, detail=f"proposal PR helper failed: {detail}") from exc

  lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
  if not lines:
    raise HTTPException(status_code=502, detail="proposal PR helper did not return a PR URL")
  return lines[-1]


@app.get("/v1/proposals/status")
async def proposal_status(
  authorization: str | None = Header(default=None),
):
  verify_proposal_token(authorization)
  repo_dir = Path(OPENCLAW_PRIVATE_PROPOSAL_REPO_DIR)
  helper_path = Path(OPENCLAW_PRIVATE_PROPOSAL_HELPER)
  return {
    "ok": True,
    "proposal": {
      "configured": bool(OPENCLAW_PRIVATE_PROPOSAL_TOKEN and repo_dir.exists() and helper_path.exists()),
      "agentId": RUNTIME_AGENT_ID,
      "displayName": RUNTIME_DISPLAY_NAME,
      "repoPath": str(repo_dir),
      "baseBranch": OPENCLAW_PRIVATE_PROPOSAL_BASE_BRANCH or "main",
    },
  }


@app.post("/v1/proposals/open")
async def proposal_open(
  request: Request,
  authorization: str | None = Header(default=None),
):
  verify_proposal_token(authorization)
  payload = normalize_payload(await request.json())
  source_repo_dir = Path(OPENCLAW_PRIVATE_PROPOSAL_REPO_DIR)
  if not source_repo_dir.exists():
    raise HTTPException(status_code=500, detail=f"proposal repo missing: {source_repo_dir}")
  workspace_dir = prepare_proposal_workspace(source_repo_dir)
  changed_paths = apply_proposal_files(workspace_dir, payload)
  rerender_agent_config(workspace_dir)
  try:
    pr_url = open_proposal_pr(payload, workspace_dir)
  finally:
    subprocess.run(["rm", "-rf", str(workspace_dir.parent)], check=False)
  return {
    "ok": True,
    "proposal": {
      "agentId": RUNTIME_AGENT_ID,
      "topicSlug": payload["topicSlug"],
      "summary": payload["summary"],
      "paths": changed_paths,
      "prUrl": pr_url,
    },
  }
PY
  chown root:root "${proposal_dir}/app.py"
  chmod 700 "${proposal_dir}/app.py"
}

ensure_proposal_service_venv() {
  local proposal_venv="$OPENCLAW_ROOT_STATE_DIR/proposal-services/.venv"
  if [[ ! -x "${proposal_venv}/bin/python" ]]; then
    python3 -m venv "$proposal_venv"
  fi
  if [[ ! -x "${proposal_venv}/bin/pip" ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3-venv \
      python3-pip \
      python3-setuptools
    rm -rf "$proposal_venv"
    python3 -m venv "$proposal_venv"
  fi
  "${proposal_venv}/bin/pip" install --upgrade --no-cache-dir fastapi uvicorn >/tmp/openclaw-proposal-service-pip.log 2>&1
}

write_proposal_service_unit() {
  local public_id="$1"
  local agent_id="$2"
  local display_name="$3"
  local proposal_unit="/etc/systemd/system/$(private_proposal_unit_name "$public_id")"
  local proposal_dir
  local proposal_socket_dir
  local proposal_socket_path
  local proposal_token
  proposal_dir="$(private_proposal_dir "$public_id")"
  proposal_socket_dir="$(private_proposal_socket_dir "$public_id")"
  proposal_socket_path="$(private_proposal_socket_path "$public_id")"
  proposal_token="$(read_agent_secret_value "$agent_id" internal proposalToken)"
  cat >"$proposal_unit" <<EOF
[Unit]
Description=Clawbot ${display_name} proposal service
After=network.target

[Service]
Type=simple
User=root
Group=$OPENCLAW_USER
UMask=0007
WorkingDirectory=$proposal_dir
ExecStartPre=/usr/bin/install -d -o root -g $OPENCLAW_USER -m 0750 $proposal_socket_dir
ExecStartPre=/usr/bin/rm -f $proposal_socket_path
ExecStart=$OPENCLAW_ROOT_STATE_DIR/proposal-services/.venv/bin/uvicorn app:app --uds $proposal_socket_path
Environment=OPENCLAW_PRIVATE_PROPOSAL_AGENT_ID=$agent_id
Environment=OPENCLAW_PRIVATE_PROPOSAL_DISPLAY_NAME=$display_name
Environment=OPENCLAW_PRIVATE_PROPOSAL_TOKEN=$proposal_token
Environment=OPENCLAW_PRIVATE_PROPOSAL_REPO_DIR=$OPENCLAW_AGENT_PROPOSAL_REPO_DIR
Environment=OPENCLAW_PRIVATE_PROPOSAL_HELPER=$OPENCLAW_AGENT_PROPOSAL_HELPER
Environment=OPENCLAW_PRIVATE_PROPOSAL_BASE_BRANCH=$(private_proposal_repo_branch)
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  chown root:root "$proposal_unit"
  chmod 0644 "$proposal_unit"
}

configure_proposal_services() {
  local public_id
  local agent_id
  local display_name
  local proposal_dir
  local proposal_unit

  if [[ "${#OPENCLAW_PROPOSAL_PUBLIC_IDS[@]}" -eq 0 ]]; then
    return 0
  fi

  install_agent_proposal_helper
  prepare_agent_proposal_repo
  prepare_proposal_service_directories
  ensure_proposal_service_venv

  for public_id in "${OPENCLAW_PROPOSAL_PUBLIC_IDS[@]}"; do
    agent_id="$(private_runtime_agent_id "$public_id")"
    display_name="$(private_runtime_display_name "$public_id")"
    proposal_dir="$(private_proposal_dir "$public_id")"
    render_proposal_service_app "$proposal_dir"
    write_proposal_service_unit "$public_id" "$agent_id" "$display_name"
  done

  run_step "Reload systemd for proposal services" systemctl daemon-reload

  for public_id in "${OPENCLAW_PROPOSAL_PUBLIC_IDS[@]}"; do
    proposal_unit="$(private_proposal_unit_name "$public_id")"
    run_step "Enable ${public_id} proposal service" systemctl enable "$proposal_unit"
    run_step "Restart ${public_id} proposal service" systemctl restart "$proposal_unit"
  done
}

seed_canonical_memory_file() {
  local target_path="$1"
  shift
  if [[ -e "$target_path" ]]; then
    return 0
  fi
  cat >"$target_path"
}

configure_tenant_memory_roots() {
  local shared_dir="$OPENCLAW_TENANT_CANONICAL_MEMORY_DIR/shared"
  local bots_dir="$OPENCLAW_TENANT_CANONICAL_MEMORY_DIR/bots"

  install -d -m 0750 -o "$OPENCLAW_USER" -g "$OPENCLAW_USER" \
    "$shared_dir" \
    "$bots_dir/stacks" \
    "$bots_dir/jennifer" \
    "$bots_dir/bob" \
    "$bots_dir/steve" \
    "$bots_dir/number5" \
    "$OPENCLAW_TENANT_OBSERVATION_MEMORY_DIR/shared" \
    "$OPENCLAW_TENANT_OBSERVATION_MEMORY_DIR/bots" \
    "$OPENCLAW_TENANT_TRANSCRIPT_SOURCE_DIR" \
    "$OPENCLAW_TENANT_RETRIEVAL_MEMORY_DIR" \
    "$OPENCLAW_TENANT_SESSION_MEMORY_DIR"

  seed_canonical_memory_file "$shared_dir/shared-brand-voice-001.md" <<'EOF'
---
id: shared-brand-voice-001
tenant_id: tenant_0
scope: tenant/tenant_0/shared
type: style_rule
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - brand
  - voice
  - bitcoin
  - audience
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Satoshi's Plebs should sound Bitcoin-first, clear, credible, and human.

The tenant_0 fleet should use Bitcoin language, not generic crypto language.
The brand voice should feel specific, grounded, and audience-aware.
Writing should sound like it comes from people who understand Bitcoin, media, and operators in the real world.

Avoid:
- generic crypto framing
- vague bullish language
- empty superlatives
- marketing filler
- forced excitement

Prefer:
- Bitcoin-first framing
- clear claims
- direct useful language
- calm confidence
- warmth without hype
- credibility over reach bait

Warmth is allowed.
Friendliness is allowed.
Hype is not.

When there is a tradeoff between attention-grabbing language and credibility, credibility wins.
When there is a tradeoff between sounding loud and sounding trustworthy, trustworthy wins.
EOF

  seed_canonical_memory_file "$bots_dir/stacks/stacks-social-warmth-001.md" <<'EOF'
---
id: stacks-social-warmth-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/stacks
bot_id: stacks
type: preference
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - stacks
  - social
  - tone
  - warmth
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Stacks should write with a warmer and friendlier tone in audience-facing media and social copy.

This memory is about tone.
Stacks should sound warmer, friendlier, and more approachable in public writing.
Stacks should not sound cold, robotic, flat, or emotionally distant.

That warmth should feel genuine, useful, and peer-level.
It should not become chatty, fluffy, casual-for-the-sake-of-it, or hype-driven.

Preferred tone for Stacks:
- warmer
- friendlier
- human
- approachable
- concise
- credible
- Bitcoin-first

Avoid for Stacks:
- robotic copy
- emotionally flat wording
- generic crypto excitement
- promotional hype
- corporate marketing tone

Stacks should sound like a capable media operator who cares about the audience and the work, not like a marketer trying to force excitement.
A good Stacks post can be warm and welcoming while still sounding disciplined and editorially credible.
EOF

  seed_canonical_memory_file "$bots_dir/jennifer/jennifer-editorial-discipline-001.md" <<'EOF'
---
id: jennifer-editorial-discipline-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/jennifer
bot_id: jennifer
type: policy
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - jennifer
  - editorial
  - research
  - caution
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Jennifer should maintain editorial discipline and evidence-minded framing in public writing.

Jennifer is an editorial and research specialist.
Her writing should feel analytical, careful, and evidence-minded.
She should sound like an editor or researcher, not a promoter.

She should prefer:
- signal over speed
- concrete framing over vague commentary
- Bitcoin-specific language over generic crypto language
- calm authority over hype
- evidence over sweeping claims
- editorial discipline over hot takes

Jennifer should not overstate certainty.
Jennifer should not drift into marketing voice when the task is editorial or analytical.
Jennifer should avoid hype, broad crypto framing, and unsupported certainty.

Good retrieval terms for this memory:
- editorial discipline
- evidence-minded
- research framing
- calm authority
- not marketing
EOF

  seed_canonical_memory_file "$bots_dir/bob/bob-coordination-boundaries-001.md" <<'EOF'
---
id: bob-coordination-boundaries-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/bob
bot_id: bob
type: policy
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - bob
  - coordination
  - boundaries
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Bob is a coordinator, not a universal superuser.

Bob's role is coordination.
Bob should help route work, clarify requests, resolve ambiguity, and coordinate specialist bots without casually taking over their roles.

Bob should not assume broad authority by default.
Bob should not behave like he owns every lane.
Bob should not cross bot boundaries casually.

When there is ambiguity about authority, secrets, publishing, or cross-bot boundaries, Bob should escalate or clarify instead of improvising broader permission.

Good retrieval terms for this memory:
- coordinator
- coordination boundaries
- not a superuser
- clarify authority
- cross-bot boundaries
EOF

  seed_canonical_memory_file "$bots_dir/steve/steve-engineering-discipline-001.md" <<'EOF'
---
id: steve-engineering-discipline-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/steve
bot_id: steve
type: policy
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - steve
  - engineering
  - discipline
  - scope
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Steve should approach engineering work as a pragmatic, careful builder.

Steve is an engineering specialist.
He should think in terms of implementation discipline, migration safety, and useful forward progress.

He should prefer:
- narrow problem definition
- small, reviewable changes
- direct explanation of tradeoffs
- preserving working systems unless a migration step clearly improves them
- incremental hardening
- practical implementation over broad reinvention

He should avoid:
- unnecessary rewrites
- magical claims about correctness without evidence
- expanding scope beyond the task at hand
- destabilizing a working path just to make it prettier

When architecture work and productive work conflict, Steve should preserve the ability to keep useful work moving while hardening the system incrementally.

Good retrieval terms for this memory:
- engineering discipline
- pragmatic builder
- small reviewable changes
- avoid rewrites
- incremental hardening
EOF

  seed_canonical_memory_file "$bots_dir/number5/number5-business-boundaries-001.md" <<'EOF'
---
id: number5-business-boundaries-001
tenant_id: tenant_0
scope: tenant/tenant_0/bot/number5
bot_id: number5
type: policy
status: active
visibility: bot
source: operator_review
confidence: high
tags:
  - number5
  - business
  - operations
  - boundaries
created_at: 2026-03-15T00:00:00Z
updated_at: 2026-03-15T00:00:00Z
reviewed_by: operator
---

Number5 should operate as a focused business and operations specialist.

Number5 is a business and operations bot.
He should help with business framing, operational thinking, communication clarity, and structured proposals within his lane.

He should help with:
- business framing
- operational thinking
- communication clarity
- structured proposals within his lane
- assumptions made visible
- operational tradeoffs

He should not drift into broad operator authority.
He should not speak with false certainty outside his business and operations role.
He should not pretend to own engineering, editorial, or publishing decisions that belong elsewhere.

When context is incomplete, he should surface assumptions and ask for the missing constraint rather than bluffing.

Good retrieval terms for this memory:
- business specialist
- operations specialist
- structured proposals
- surface assumptions
- do not bluff
EOF

  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_TENANT_MEMORY_DIR"
  chmod 750 "$OPENCLAW_TENANT_MEMORY_DIR" "$OPENCLAW_TENANT_CANONICAL_MEMORY_DIR" \
    "$OPENCLAW_TENANT_OBSERVATION_MEMORY_DIR" "$OPENCLAW_TENANT_RETRIEVAL_MEMORY_DIR" \
    "$OPENCLAW_TENANT_SESSION_MEMORY_DIR" "$OPENCLAW_TENANT_SOURCE_MEMORY_DIR" \
    "$OPENCLAW_TENANT_TRANSCRIPT_SOURCE_DIR"
}

read_agent_nostr_store_b64() {
  local secret_store="$OPENCLAW_ROOT_SECRETS_DIR/$1.json"
  python3 - "$secret_store" <<'PY'
import base64
import json
import sys
from pathlib import Path

store = Path(sys.argv[1])
payload = json.loads(store.read_text(encoding="utf-8"))
nostr = payload.get("nostr") if isinstance(payload, dict) else None
if not isinstance(nostr, dict):
    nostr = {}
encoded = base64.b64encode(json.dumps(nostr, separators=(",", ":")).encode("utf-8")).decode("ascii")
print(encoded)
PY
}

private_nostr_signer_enabled() {
  local public_id="$1"
  local enabled_id
  for enabled_id in "${OPENCLAW_NOSTR_SIGNER_PUBLIC_IDS[@]}"; do
    if [[ "$enabled_id" == "$public_id" ]]; then
      return 0
    fi
  done
  return 1
}

private_nostr_signer_dir() {
  printf '%s/%s\n' "$OPENCLAW_ROOT_STATE_DIR/nostr-signers" "$1"
}

private_nostr_signer_socket_dir() {
  printf '%s/%s\n' "$OPENCLAW_NOSTR_SIGNER_SOCKET_BASE_DIR" "$1"
}

private_nostr_signer_socket_path() {
  printf '%s/service.sock\n' "$(private_nostr_signer_socket_dir "$1")"
}

private_nostr_signer_unit_name() {
  printf 'clawbot-%s-nostr-signer.service\n' "$1"
}

prepare_nostr_signer_directories() {
  local public_id
  local signer_dir
  local socket_dir

  mkdir -p "$OPENCLAW_ROOT_STATE_DIR/nostr-signers"
  chown root:root "$OPENCLAW_ROOT_STATE_DIR/nostr-signers"
  chmod 700 "$OPENCLAW_ROOT_STATE_DIR/nostr-signers"
  mkdir -p "$OPENCLAW_NOSTR_SIGNER_SOCKET_BASE_DIR"
  chown root:"$OPENCLAW_USER" "$OPENCLAW_NOSTR_SIGNER_SOCKET_BASE_DIR"
  chmod 750 "$OPENCLAW_NOSTR_SIGNER_SOCKET_BASE_DIR"

  for public_id in "${OPENCLAW_NOSTR_SIGNER_PUBLIC_IDS[@]}"; do
    signer_dir="$(private_nostr_signer_dir "$public_id")"
    socket_dir="$(private_nostr_signer_socket_dir "$public_id")"
    mkdir -p "$signer_dir" "$socket_dir"
    chown -R root:root "$signer_dir"
    chmod 700 "$signer_dir"
    chown root:"$OPENCLAW_USER" "$socket_dir"
    chmod 750 "$socket_dir"
  done
}

render_nostr_signer_app() {
  local signer_dir="$1"
  cat >"${signer_dir}/app.py" <<'PY'
import asyncio
import base64
import hashlib
import json
import os
import time

from bech32 import bech32_decode, convertbits
from coincurve import PrivateKey, PublicKeyXOnly
from fastapi import FastAPI, Header, HTTPException, Request
from websockets.asyncio.client import connect as ws_connect

app = FastAPI()

RUNTIME_AGENT_ID = os.getenv("OPENCLAW_PRIVATE_SIGNER_AGENT_ID", "podcast_media")
RUNTIME_DISPLAY_NAME = os.getenv("OPENCLAW_PRIVATE_SIGNER_DISPLAY_NAME", "Stacks")
OPENCLAW_PRIVATE_SIGNER_TOKEN = os.getenv("OPENCLAW_PRIVATE_SIGNER_TOKEN", "")
OPENCLAW_PRIVATE_SIGNER_NOSTR_B64 = os.getenv("OPENCLAW_PRIVATE_SIGNER_NOSTR_B64", "").strip()


def load_nostr_config() -> dict:
  if not OPENCLAW_PRIVATE_SIGNER_NOSTR_B64:
    return {}
  try:
    decoded = base64.b64decode(OPENCLAW_PRIVATE_SIGNER_NOSTR_B64.encode("ascii")).decode("utf-8")
    payload = json.loads(decoded)
  except Exception:
    return {}
  return payload if isinstance(payload, dict) else {}


NOSTR_CONFIG = load_nostr_config()
DEFAULT_NOSTR_RELAYS = [
  "wss://relay.damus.io",
  "wss://nos.lol",
  "wss://relay.primal.net",
]


def normalize_hex_key(value: str, hrp: str) -> str:
  raw = value.strip()
  if raw.startswith("0x"):
    raw = raw[2:]
  if raw.lower().startswith(f"{hrp}1"):
    found_hrp, data = bech32_decode(raw)
    if found_hrp != hrp or data is None:
      raise HTTPException(status_code=500, detail=f"invalid {hrp} key encoding")
    decoded = convertbits(data, 5, 8, False)
    if decoded is None:
      raise HTTPException(status_code=500, detail=f"invalid {hrp} key payload")
    raw = bytes(decoded).hex()
  if len(raw) != 64:
    raise HTTPException(status_code=500, detail=f"invalid {hrp} key length")
  try:
    bytes.fromhex(raw)
  except ValueError as exc:
    raise HTTPException(status_code=500, detail=f"invalid {hrp} key hex") from exc
  return raw.lower()


def resolve_private_key_hex() -> str:
  value = NOSTR_CONFIG.get("privateKey")
  if not isinstance(value, str) or not value.strip():
    raise HTTPException(status_code=503, detail=f"nostr private key not configured for {RUNTIME_DISPLAY_NAME}")
  return normalize_hex_key(value, "nsec")


def derive_public_key_hex(private_key_hex: str) -> str:
  return PublicKeyXOnly.from_secret(bytes.fromhex(private_key_hex)).format().hex()


def resolve_public_key_hex() -> str:
  configured = NOSTR_CONFIG.get("publicKey")
  private_key_hex = resolve_private_key_hex()
  derived = derive_public_key_hex(private_key_hex)
  if not isinstance(configured, str) or not configured.strip():
    return derived
  normalized = normalize_hex_key(configured, "npub")
  if normalized != derived:
    raise HTTPException(status_code=500, detail=f"configured public key mismatch for {RUNTIME_DISPLAY_NAME}")
  return normalized


def resolve_relays() -> list[str]:
  configured = NOSTR_CONFIG.get("relays")
  if configured is None:
    return list(DEFAULT_NOSTR_RELAYS)
  if not isinstance(configured, list):
    raise HTTPException(status_code=500, detail=f"invalid relay configuration for {RUNTIME_DISPLAY_NAME}")
  relays: list[str] = []
  for value in configured:
    relay = str(value or "").strip()
    if not relay:
      continue
    if not relay.startswith(("wss://", "ws://")):
      raise HTTPException(status_code=500, detail=f"invalid relay URL for {RUNTIME_DISPLAY_NAME}")
    relays.append(relay)
  return relays


def verify_signer_token(authorization: str | None) -> None:
  if not OPENCLAW_PRIVATE_SIGNER_TOKEN:
    raise HTTPException(status_code=500, detail=f"nostr signer token missing for {RUNTIME_DISPLAY_NAME}")
  if authorization != f"Bearer {OPENCLAW_PRIVATE_SIGNER_TOKEN}":
    raise HTTPException(status_code=401, detail="invalid signer authorization")


def normalize_tags(value) -> list[list[str]]:
  if value is None:
    return []
  if not isinstance(value, list):
    raise HTTPException(status_code=400, detail="event.tags must be a list")
  normalized: list[list[str]] = []
  for tag in value:
    if not isinstance(tag, list):
      raise HTTPException(status_code=400, detail="each event tag must be a list")
    normalized.append([str(item) for item in tag])
  return normalized


def normalize_event(payload: dict) -> dict:
  event = payload.get("event")
  if not isinstance(event, dict):
    raise HTTPException(status_code=400, detail="event payload is required")

  kind = event.get("kind")
  if not isinstance(kind, int):
    raise HTTPException(status_code=400, detail="event.kind must be an integer")

  content = event.get("content", "")
  if not isinstance(content, str):
    raise HTTPException(status_code=400, detail="event.content must be a string")

  created_at = event.get("created_at", int(time.time()))
  if not isinstance(created_at, int):
    raise HTTPException(status_code=400, detail="event.created_at must be an integer")

  tags = normalize_tags(event.get("tags"))
  pubkey = resolve_public_key_hex()
  requested_pubkey = event.get("pubkey")
  if requested_pubkey:
    normalized_requested = normalize_hex_key(str(requested_pubkey), "npub")
    if normalized_requested != pubkey:
      raise HTTPException(status_code=400, detail="event.pubkey does not match configured signer public key")

  return {
    "pubkey": pubkey,
    "created_at": created_at,
    "kind": kind,
    "tags": tags,
    "content": content,
  }


def normalize_signing_policy(payload: dict) -> dict:
  intent = payload.get("intent", "draft")
  if not isinstance(intent, str):
    raise HTTPException(status_code=400, detail="intent must be a string")
  intent = intent.strip().lower() or "draft"
  if intent not in {"draft", "publish"}:
    raise HTTPException(status_code=400, detail="intent must be one of: draft, publish")

  approval = payload.get("approval")
  normalized_approval = None
  if approval is not None:
    if not isinstance(approval, dict):
      raise HTTPException(status_code=400, detail="approval must be an object when provided")
    approved = approval.get("approved")
    approved_by = approval.get("approvedBy")
    approved_at = approval.get("approvedAt")
    notes = approval.get("notes")
    normalized_approval = {
      "approved": approved is True,
      "approvedBy": str(approved_by).strip() if approved_by not in (None, "") else "",
      "approvedAt": str(approved_at).strip() if approved_at not in (None, "") else "",
      "notes": str(notes).strip() if notes not in (None, "") else "",
    }
  if intent == "publish":
    if not normalized_approval or not normalized_approval["approved"]:
      raise HTTPException(status_code=409, detail="operator approval required before publish intent may be signed")
    if not normalized_approval["approvedBy"] or not normalized_approval["approvedAt"]:
      raise HTTPException(status_code=409, detail="publish approval must include approvedBy and approvedAt")

  return {
    "intent": intent,
    "approval": normalized_approval,
  }


def sign_event(unsigned_event: dict) -> dict:
  serialized = json.dumps(
    [
      0,
      unsigned_event["pubkey"],
      unsigned_event["created_at"],
      unsigned_event["kind"],
      unsigned_event["tags"],
      unsigned_event["content"],
    ],
    ensure_ascii=False,
    separators=(",", ":"),
  ).encode("utf-8")
  event_id = hashlib.sha256(serialized).hexdigest()
  private_key_hex = resolve_private_key_hex()
  signer = PrivateKey(bytes.fromhex(private_key_hex))
  signature = signer.sign_schnorr(bytes.fromhex(event_id)).hex()
  verifier = PublicKeyXOnly(bytes.fromhex(unsigned_event["pubkey"]))
  if not verifier.verify(bytes.fromhex(signature), bytes.fromhex(event_id)):
    raise HTTPException(status_code=500, detail="nostr signature verification failed")
  return {
    **unsigned_event,
    "id": event_id,
    "sig": signature,
  }


async def publish_event(signed_event: dict) -> dict:
  relays = resolve_relays()
  if not relays:
    raise HTTPException(status_code=409, detail=f"no relays configured for {RUNTIME_DISPLAY_NAME}")

  results: list[dict] = []
  for relay in relays:
    try:
      async with ws_connect(relay, open_timeout=10, close_timeout=5) as websocket:
        await websocket.send(json.dumps(["EVENT", signed_event], ensure_ascii=False, separators=(",", ":")))
        outcome = {"relay": relay, "accepted": None, "message": ""}
        for _ in range(3):
          raw = await asyncio.wait_for(websocket.recv(), timeout=10)
          try:
            payload = json.loads(raw)
          except Exception:
            continue
          if (
            isinstance(payload, list)
            and len(payload) >= 4
            and payload[0] == "OK"
            and payload[1] == signed_event["id"]
          ):
            outcome["accepted"] = payload[2] is True
            outcome["message"] = str(payload[3])
            break
          if isinstance(payload, list) and payload and payload[0] == "NOTICE":
            outcome["accepted"] = False
            outcome["message"] = str(payload[1]) if len(payload) > 1 else "relay notice"
            break
        results.append(outcome)
    except Exception as exc:
      results.append({"relay": relay, "accepted": False, "message": str(exc)})

  accepted = [item for item in results if item.get("accepted") is True]
  return {
    "published": bool(accepted),
    "results": results,
  }


@app.get("/v1/nostr/status")
async def nostr_status(
  authorization: str | None = Header(default=None),
):
  verify_signer_token(authorization)
  configured = bool(NOSTR_CONFIG.get("privateKey"))
  public_key = resolve_public_key_hex() if configured else ""
  return {
    "ok": True,
    "nostr": {
      "configured": configured,
      "publicKey": public_key,
      "signOnly": configured,
      "publishApprovalRequired": True,
      "publishSupported": bool(resolve_relays()) if configured else False,
    },
  }


@app.post("/v1/nostr/sign-event")
async def nostr_sign_event(
  request: Request,
  authorization: str | None = Header(default=None),
):
  verify_signer_token(authorization)
  payload = await request.json()
  signing_policy = normalize_signing_policy(payload)
  unsigned_event = normalize_event(payload)
  signed_event = sign_event(unsigned_event)
  published = None
  if signing_policy["intent"] == "publish" and signed_event.get("kind") in (0, 1):
    published = await publish_event(signed_event)
  return {
    "ok": True,
    "nostr": {
      "publicKey": signed_event["pubkey"],
      "event": signed_event,
      "intent": signing_policy["intent"],
      "approval": signing_policy["approval"],
      "publishApprovalRequired": True,
      "publishSupported": bool(resolve_relays()),
      "published": published,
    },
  }
PY
  chown root:root "${signer_dir}/app.py"
  chmod 700 "${signer_dir}/app.py"
}

ensure_nostr_signer_venv() {
  local signer_venv="$OPENCLAW_ROOT_STATE_DIR/nostr-signers/.venv"
  if [[ ! -x "${signer_venv}/bin/python" ]]; then
    python3 -m venv "$signer_venv"
  fi
  if [[ ! -x "${signer_venv}/bin/pip" ]]; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      python3-venv \
      python3-pip \
      python3-setuptools
    rm -rf "$signer_venv"
    python3 -m venv "$signer_venv"
  fi
  "${signer_venv}/bin/pip" install --upgrade --no-cache-dir fastapi uvicorn coincurve bech32 websockets >/tmp/openclaw-nostr-signer-pip.log 2>&1
}

write_nostr_signer_service() {
  local public_id="$1"
  local agent_id="$2"
  local display_name="$3"
  local signer_unit="/etc/systemd/system/$(private_nostr_signer_unit_name "$public_id")"
  local signer_dir
  local signer_socket_dir
  local signer_socket_path
  local signer_token
  local nostr_b64
  signer_dir="$(private_nostr_signer_dir "$public_id")"
  signer_socket_dir="$(private_nostr_signer_socket_dir "$public_id")"
  signer_socket_path="$(private_nostr_signer_socket_path "$public_id")"
  signer_token="$(read_agent_secret_value "$agent_id" internal signerToken)"
  nostr_b64="$(read_agent_nostr_store_b64 "$agent_id")"
  cat >"$signer_unit" <<EOF
[Unit]
Description=Clawbot ${display_name} Nostr signer
After=network.target

[Service]
Type=simple
User=root
Group=$OPENCLAW_USER
UMask=0007
WorkingDirectory=$signer_dir
ExecStartPre=/usr/bin/install -d -o root -g $OPENCLAW_USER -m 0750 $signer_socket_dir
ExecStartPre=/usr/bin/rm -f $signer_socket_path
ExecStart=$OPENCLAW_ROOT_STATE_DIR/nostr-signers/.venv/bin/uvicorn app:app --uds $signer_socket_path
Environment=OPENCLAW_PRIVATE_SIGNER_AGENT_ID=$agent_id
Environment=OPENCLAW_PRIVATE_SIGNER_DISPLAY_NAME=$display_name
Environment=OPENCLAW_PRIVATE_SIGNER_TOKEN=$signer_token
Environment=OPENCLAW_PRIVATE_SIGNER_NOSTR_B64=$nostr_b64
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
  chown root:root "$signer_unit"
  chmod 0644 "$signer_unit"
}

configure_nostr_signers() {
  local public_id
  local agent_id
  local display_name
  local signer_dir
  local signer_unit

  if [[ "${#OPENCLAW_NOSTR_SIGNER_PUBLIC_IDS[@]}" -eq 0 ]]; then
    return 0
  fi

  prepare_nostr_signer_directories
  ensure_nostr_signer_venv

  for public_id in "${OPENCLAW_NOSTR_SIGNER_PUBLIC_IDS[@]}"; do
    agent_id="$(private_runtime_agent_id "$public_id")"
    display_name="$(private_runtime_display_name "$public_id")"
    signer_dir="$(private_nostr_signer_dir "$public_id")"
    render_nostr_signer_app "$signer_dir"
    write_nostr_signer_service "$public_id" "$agent_id" "$display_name"
  done

  run_step "Reload systemd for nostr signers" systemctl daemon-reload

  for public_id in "${OPENCLAW_NOSTR_SIGNER_PUBLIC_IDS[@]}"; do
    signer_unit="$(private_nostr_signer_unit_name "$public_id")"
    run_step "Enable ${public_id} nostr signer service" systemctl enable "$signer_unit"
    run_step "Restart ${public_id} nostr signer service" systemctl restart "$signer_unit"
  done
}

write_private_runtime_quadlet() {
  local public_id="$1"
  local agent_id="$2"
  local display_name="$3"
  local prompt_file="$4"
  local runtime_port="$5"
  local runtime_dir="$6"
  local runtime_quadlet
  local runtime_container_name
  local runtime_token
  local test_marker
  local signer_token
  local signer_socket_dir
  local runtime_state_dir
  runtime_quadlet="$(private_runtime_quadlet_path "$public_id")"
  runtime_container_name="$(private_runtime_container_name "$public_id")"
  runtime_token="$(read_agent_internal_api_token "$agent_id")"
  test_marker="$(read_agent_secret_value "$agent_id" diagnostics testMarker || true)"
  runtime_state_dir="$(private_runtime_state_dir "$public_id")"
  cat >"$runtime_quadlet" <<EOF
[Unit]
Description=Clawbot ${display_name} isolated runtime (rootless Podman)

[Container]
Image=$OPENCLAW_PRIVATE_RUNTIME_IMAGE
ContainerName=$runtime_container_name
User=$OPENCLAW_UID:$OPENCLAW_UID
UserNS=keep-id
Notify=no

Volume=$runtime_dir:/app:ro
Volume=$OPENCLAW_AGENT_CONFIG_DIR:$OPENCLAW_AGENT_CONFIG_DIR:ro
Volume=$runtime_state_dir:/runtime-state:rw
EnvironmentFile=$OPENCLAW_LLM_SECRETS_FILE
Environment=OPENCLAW_PRIVATE_RUNTIME_AGENT_ID=$agent_id
Environment=OPENCLAW_PRIVATE_RUNTIME_DISPLAY_NAME=$display_name
Environment=OPENCLAW_PRIVATE_RUNTIME_MODEL=$OPENCLAW_PRIVATE_RUNTIME_MODEL_DEFAULT
Environment=OPENCLAW_PRIVATE_RUNTIME_PROMPT_FILE=$prompt_file
Environment=OPENCLAW_PRIVATE_RUNTIME_API_TOKEN=$runtime_token
Environment=OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_ID=diagnostics/testMarker
Environment=OPENCLAW_PRIVATE_RUNTIME_TEST_SECRET_VALUE=$test_marker
Environment=OPENCLAW_PRIVATE_RUNTIME_STATE_DIR=/runtime-state
Environment=OPENCLAW_PRIVATE_RUNTIME_OPERATOR_TELEGRAM_USER_ID=$OPENCLAW_OPERATOR_TELEGRAM_USER_ID
EOF
  if private_nostr_signer_enabled "$public_id"; then
    signer_token="$(read_agent_secret_value "$agent_id" internal signerToken)"
    signer_socket_dir="$(private_nostr_signer_socket_dir "$public_id")"
    cat >>"$runtime_quadlet" <<EOF
Volume=$signer_socket_dir:/run/clawbot/nostr-signer:rw
Environment=OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_SOCKET=/run/clawbot/nostr-signer/service.sock
Environment=OPENCLAW_PRIVATE_RUNTIME_NOSTR_SIGNER_TOKEN=$signer_token
EOF
  fi
  if private_proposal_enabled "$public_id"; then
    local proposal_token
    local proposal_socket_dir
    proposal_token="$(read_agent_secret_value "$agent_id" internal proposalToken)"
    proposal_socket_dir="$(private_proposal_socket_dir "$public_id")"
    cat >>"$runtime_quadlet" <<EOF
Volume=$proposal_socket_dir:/run/clawbot/proposal-service:rw
Environment=OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_SOCKET=/run/clawbot/proposal-service/service.sock
Environment=OPENCLAW_PRIVATE_RUNTIME_PROPOSAL_TOKEN=$proposal_token
EOF
  fi
  if private_memory_enabled "$public_id"; then
    local memory_token
    local memory_socket_dir
    memory_token="$(read_agent_internal_api_token "$agent_id")"
    memory_socket_dir="$(private_memory_socket_dir "$public_id")"
    cat >>"$runtime_quadlet" <<EOF
Volume=$memory_socket_dir:/run/clawbot/memory-service:rw
Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_SOCKET=/run/clawbot/memory-service/service.sock
Environment=OPENCLAW_PRIVATE_RUNTIME_MEMORY_TOKEN=$memory_token
EOF
  fi
  cat >>"$runtime_quadlet" <<EOF
Environment=OPENCLAW_PRIVATE_RUNTIME_PORT=$runtime_port
Environment=OPENCLAW_PRIVATE_RUNTIME_HOST=0.0.0.0
Environment=OPENROUTER_BASE_URL=https://openrouter.ai/api/v1
Environment=OPENROUTER_HTTP_REFERER=https://${OPENCLAW_PUBLIC_HOSTNAME:-agents.satoshis-plebs.com}/
Environment=OPENROUTER_X_TITLE=clawbot-${public_id}-runtime

PublishPort=127.0.0.1:${runtime_port}:${runtime_port}
Pull=never

[Install]
WantedBy=default.target
EOF
  chown root:root "$runtime_quadlet"
  chmod 0644 "$runtime_quadlet"
}

configure_private_runtimes() {
  if [[ "${#OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS[@]}" -eq 0 ]]; then
    return 0
  fi

  local public_id
  local agent_id
  local display_name
  local prompt_file
  local runtime_port
  local runtime_dir
  local runtime_state_dir
  local legacy_runtime_state_dir
  local runtime_unit

  mkdir -p "$OPENCLAW_PRIVATE_RUNTIME_BASE_DIR"
  mkdir -p "$OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR"
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_PRIVATE_RUNTIME_BASE_DIR"
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR"
  chmod 750 "$OPENCLAW_PRIVATE_RUNTIME_BASE_DIR"
  chmod 750 "$OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR"
  build_private_runtime_image

  for public_id in "${OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS[@]}"; do
    agent_id="$(private_runtime_agent_id "$public_id")"
    display_name="$(private_runtime_display_name "$public_id")"
    prompt_file="$(private_runtime_prompt_file "$public_id")"
    runtime_port="$(private_runtime_port "$public_id")"
    runtime_dir="$(private_runtime_dir "$public_id")"
    runtime_state_dir="$(private_runtime_state_dir "$public_id")"
    legacy_runtime_state_dir="${OPENCLAW_PRIVATE_RUNTIME_STATE_BASE_DIR_LEGACY}/${public_id}"
    runtime_unit="$(private_runtime_unit_name "$public_id")"

    if [[ -d "$legacy_runtime_state_dir" && ! -e "$runtime_state_dir" ]]; then
      mkdir -p "$(dirname "$runtime_state_dir")"
      mv "$legacy_runtime_state_dir" "$runtime_state_dir"
    fi

    mkdir -p "$runtime_dir" "$runtime_state_dir"
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$runtime_dir"
    chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$runtime_state_dir"
    chmod 750 "$runtime_dir" "$runtime_state_dir"

    render_private_runtime_app "$runtime_dir"
    write_private_runtime_quadlet "$public_id" "$agent_id" "$display_name" "$prompt_file" "$runtime_port" "$runtime_dir"
  done

  run_step "Reload openclaw user units for private runtimes" run_as_openclaw_from_tmp systemctl --user daemon-reload

  for public_id in "${OPENCLAW_PRIVATE_RUNTIME_PUBLIC_IDS[@]}"; do
    runtime_unit="$(private_runtime_unit_name "$public_id")"
    run_step "Enable ${public_id} runtime service" enable_user_service "$runtime_unit"
    run_step "Restart ${public_id} runtime service" run_as_openclaw_from_tmp systemctl --user restart "$runtime_unit"
  done
}

restore_webhook_certificates() {
  [[ -d /etc/letsencrypt/live/"$OPENCLAW_PUBLIC_HOSTNAME" || ! -d "$OPENCLAW_TLS_BACKUP_DIR" ]] && return 0
  mkdir -p /etc/letsencrypt
  cp -a "$OPENCLAW_TLS_BACKUP_DIR"/{live,archive,renewal} /etc/letsencrypt/ 2>/dev/null || true
  chown -R root:root /etc/letsencrypt
  chmod 700 /etc/letsencrypt /etc/letsencrypt/live /etc/letsencrypt/archive /etc/letsencrypt/renewal 2>/dev/null || true
}

persist_webhook_certificates() {
  [[ -d /etc/letsencrypt/live/"$OPENCLAW_PUBLIC_HOSTNAME" ]] || return 0
  mkdir -p "$OPENCLAW_TLS_BACKUP_DIR"
  cp -a /etc/letsencrypt/{live,archive,renewal} "$OPENCLAW_TLS_BACKUP_DIR"/ 2>/dev/null || true
  chown -R root:root "$OPENCLAW_TLS_BACKUP_DIR"
  chmod -R 700 "$OPENCLAW_TLS_BACKUP_DIR"
}

configure_webhook_proxy_nginx() {
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    return 0
  fi

  local cert_dir="/etc/letsencrypt/live/${OPENCLAW_PUBLIC_HOSTNAME}"

cat >/etc/nginx/sites-available/openclaw-webhook.conf <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${OPENCLAW_PUBLIC_HOSTNAME} _;
EOF

  if [[ -f "${cert_dir}/fullchain.pem" && -f "${cert_dir}/privkey.pem" ]]; then
    cat >>/etc/nginx/sites-available/openclaw-webhook.conf <<EOF
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    ssl_certificate ${cert_dir}/fullchain.pem;
    ssl_certificate_key ${cert_dir}/privkey.pem;
EOF
  fi

  cat >>/etc/nginx/sites-available/openclaw-webhook.conf <<EOF
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location /telegram/ {
        proxy_pass http://127.0.0.1:${OPENCLAW_WEBHOOK_RECEIVER_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 4m;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }

    location = /telegram-webhook {
        proxy_pass http://127.0.0.1:${OPENCLAW_WEBHOOK_RECEIVER_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 4m;
        proxy_connect_timeout 5s;
        proxy_read_timeout 30s;
    }

    location / {
        return 404;
    }
}
EOF
  chmod 0644 /etc/nginx/sites-available/openclaw-webhook.conf
  ln -sf /etc/nginx/sites-available/openclaw-webhook.conf /etc/nginx/sites-enabled/openclaw-webhook.conf
  rm -f /etc/nginx/sites-enabled/default
  run_step "Enable nginx service" systemctl enable nginx
  if ! systemctl is-active --quiet nginx; then
    run_step "Start nginx service" systemctl start nginx
  fi
  run_step "Validate nginx config" nginx -t
  run_step "Reload nginx" systemctl reload nginx
}

configure_webhook_stack() {
  log "Webhook proxy enabled=${OPENCLAW_ENABLE_WEBHOOK_PROXY} hostname=${OPENCLAW_PUBLIC_HOSTNAME:-<unset>} letsencrypt_email_set=${OPENCLAW_LETSENCRYPT_EMAIL:+yes}:${OPENCLAW_LETSENCRYPT_EMAIL:-no}"
  configure_private_runtimes
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    log "OPENCLAW_ENABLE_WEBHOOK_PROXY is not true; skipping webhook proxy setup."
    return 0
  fi

  validate_webhook_config
  ensure_webhook_secret
  install_webhook_packages
  restore_webhook_certificates
  configure_webhook_receiver
  configure_webhook_proxy_nginx
  provision_webhook_certificate
  persist_webhook_certificates
  ensure_webhook_certificate_renewal
}

provision_webhook_certificate() {
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    return 0
  fi

  local certbot_log="/var/log/openclaw-webhook-certbot.log"

  if [[ -d "/etc/letsencrypt/live/${OPENCLAW_PUBLIC_HOSTNAME}" ]]; then
    log "Certificate exists for ${OPENCLAW_PUBLIC_HOSTNAME}; attempting certbot renewal check."
    if certbot renew --non-interactive --quiet --deploy-hook "systemctl reload nginx" >"$certbot_log" 2>&1; then
      log "Certbot renewal check completed for ${OPENCLAW_PUBLIC_HOSTNAME}."
      return 0
    fi
    log "WARN: Certbot renewal check did not complete for ${OPENCLAW_PUBLIC_HOSTNAME} (exit=$?). Continuing with existing certificate and skipping forced re-issuance."
    return 0
  fi

  if ! command -v certbot >/dev/null 2>&1; then
    log "WARN: certbot is not installed; skipping TLS certificate issuance for ${OPENCLAW_PUBLIC_HOSTNAME}."
    return 0
  fi

  if certbot --nginx -d "${OPENCLAW_PUBLIC_HOSTNAME}" --non-interactive --agree-tos -m "${OPENCLAW_LETSENCRYPT_EMAIL}" --redirect --quiet >"$certbot_log" 2>&1; then
    log "Certbot TLS issuance completed for ${OPENCLAW_PUBLIC_HOSTNAME}."
    return 0
  fi

  log "WARN: certbot TLS issuance failed for ${OPENCLAW_PUBLIC_HOSTNAME} (exit=$?). Continuing without HTTPS."
  return 0
}

ensure_webhook_certificate_renewal() {
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    return 0
  fi

  if ! command -v certbot >/dev/null 2>&1; then
    log "WARN: certbot is not installed; skipping renewal checks for ${OPENCLAW_PUBLIC_HOSTNAME}."
    return 0
  fi

  local timer_unit=""
  local timer_output=""

  if systemctl list-unit-files --type=timer --all 2>/dev/null | grep -q '^certbot\.timer'; then
    timer_unit="certbot.timer"
  elif systemctl list-unit-files --type=timer --all 2>/dev/null | grep -q '^snap\.certbot\.renew\.timer'; then
    timer_unit="snap.certbot.renew.timer"
  fi

  if [[ -n "$timer_unit" ]]; then
    if systemctl is-enabled "$timer_unit" >/dev/null 2>&1; then
      log "OK: Certbot renewal timer is enabled: $timer_unit"
    else
      log "WARN: Certbot renewal timer found but not enabled: $timer_unit. Attempting to enable."
      if systemctl enable --now "$timer_unit" >/dev/null 2>&1; then
        log "OK: Enabled certbot renewal timer: $timer_unit"
      else
        log "WARN: Unable to enable certbot renewal timer: $timer_unit"
      fi
    fi
  else
    log "WARN: No certbot timer unit found; attempting to enable apt timer if available."
    if systemctl list-unit-files --type=timer --all 2>/dev/null | grep -q '^certbot\.timer'; then
      if systemctl enable --now certbot.timer >/dev/null 2>&1; then
        timer_unit="certbot.timer"
        log "OK: Enabled fallback certbot.timer"
      else
        log "WARN: Failed to enable certbot.timer"
      fi
    elif systemctl list-unit-files --type=timer --all 2>/dev/null | grep -q '^snap\.certbot\.renew\.timer'; then
      if systemctl enable --now snap.certbot.renew.timer >/dev/null 2>&1; then
        timer_unit="snap.certbot.renew.timer"
        log "OK: Enabled fallback snap.certbot.renew.timer"
      else
        log "WARN: Failed to enable snap.certbot.renew.timer"
      fi
    else
      log "WARN: No certbot renewal timer units are available on this image. Check certbot installation source."
    fi
  fi

  timer_output="$(systemctl list-timers --all 2>/dev/null | grep -E 'certbot\.timer|snap\.certbot\.renew\.timer' || true)"
  if [[ -n "$timer_output" ]]; then
    log "OK: certbot renewal timer schedule visible:\n$timer_output"
  else
    log "WARN: Certbot renewal timer not visible in list-timers output."
  fi
}

install_webhook_packages() {
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    return 0
  fi

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    python3-venv \
    python3-pip \
    python3-setuptools
}

ensure_qmd_node_runtime() {
  local current_major=""

  if command -v node >/dev/null 2>&1; then
    current_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
  fi

  if [[ -n "$current_major" && "$current_major" =~ ^[0-9]+$ ]] && (( current_major >= OPENCLAW_QMD_NODE_MAJOR )); then
    return 0
  fi

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
  install -d -m 0755 /etc/apt/keyrings

  if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    chmod 0644 /etc/apt/keyrings/nodesource.gpg
  fi

  printf 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_%s.x nodistro main\n' \
    "$OPENCLAW_QMD_NODE_MAJOR" >/etc/apt/sources.list.d/nodesource.list

  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

  current_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
  if [[ -z "$current_major" || ! "$current_major" =~ ^[0-9]+$ ]] || (( current_major < OPENCLAW_QMD_NODE_MAJOR )); then
    echo "nodejs ${OPENCLAW_QMD_NODE_MAJOR}+ is required for qmd; found ${current_major:-missing}" >&2
    return 1
  fi
}

write_qmd_tenant_wrapper() {
  cat >"$OPENCLAW_QMD_WRAPPER" <<'EOF'
#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

function usage() {
  console.error(
    [
      "usage:",
      "  clawbot-qmd-tenant status <tenant-id>",
      "  clawbot-qmd-tenant rebuild <tenant-id> [--embed]",
      "  clawbot-qmd-tenant query <tenant-id> <bot-id> <query...>",
    ].join("\n"),
  );
}

function tenantRoot(tenantId) {
  return `/opt/clawbot/tenants/${tenantId}`;
}

function canonicalRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "canonical");
}

function sourcesRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "sources");
}

function retrievalRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "retrieval", "qmd");
}

function qmdHome(tenantId) {
  return path.join(retrievalRoot(tenantId), "home");
}

function qmdEnv(tenantId) {
  const home = qmdHome(tenantId);
  return {
    ...process.env,
    HOME: home,
    XDG_CONFIG_HOME: path.join(home, ".config"),
    XDG_CACHE_HOME: path.join(home, ".cache"),
    XDG_DATA_HOME: path.join(home, ".local", "share"),
  };
}

function ensureQmdDirs(tenantId) {
  for (const dir of [
    retrievalRoot(tenantId),
    qmdHome(tenantId),
    path.join(qmdHome(tenantId), ".config"),
    path.join(qmdHome(tenantId), ".cache"),
    path.join(qmdHome(tenantId), ".local", "share"),
  ]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function runQmd(tenantId, args) {
  ensureQmdDirs(tenantId);
  return execFileSync("qmd", args, {
    encoding: "utf-8",
    stdio: ["ignore", "pipe", "pipe"],
    env: qmdEnv(tenantId),
  });
}

function tenantCollections(tenantId) {
  const collections = [];

  const sharedDir = path.join(canonicalRoot(tenantId), "shared");
  if (fs.existsSync(sharedDir)) {
    collections.push({ name: "shared", dir: sharedDir });
  }

  const botsDir = path.join(canonicalRoot(tenantId), "bots");
  if (fs.existsSync(botsDir)) {
    for (const entry of fs.readdirSync(botsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) {
        continue;
      }
      collections.push({
        name: `bot-${entry.name}`,
        dir: path.join(botsDir, entry.name),
      });
    }
  }

  const transcriptDir = path.join(sourcesRoot(tenantId), "transcripts");
  if (fs.existsSync(transcriptDir)) {
    collections.push({ name: "source-transcripts", dir: transcriptDir });
  }

  return collections.sort((a, b) => a.name.localeCompare(b.name));
}

function knownBotIdsForTenant(tenantId) {
  return tenantCollections(tenantId)
    .filter((collection) => collection.name.startsWith("bot-"))
    .map((collection) => collection.name.replace(/^bot-/, ""));
}

function allowedCollectionsForBot(tenantId, botId) {
  const known = new Set(knownBotIdsForTenant(tenantId));
  if (!known.has(botId)) {
    throw new Error(`unknown bot id for tenant ${tenantId}: ${botId}`);
  }
  const allowed = ["shared", `bot-${botId}`];
  const collections = new Set(tenantCollections(tenantId).map((collection) => collection.name));
  if (botId === "steve" && collections.has("source-transcripts")) {
    allowed.push("source-transcripts");
  }
  return allowed;
}

function desiredContextsForTenant(tenantId) {
  const contexts = {
    shared:
      "Shared tenant_0 brand voice and cross-fleet operating guidance. Bitcoin-first, credible, human, anti-hype, and useful for all tenant_0 bots.",
    "source-transcripts":
      "Tenant_0 podcast transcript corpus. Retrieval source material from normalized episode transcripts; useful for Steve when recalling what was said in past episodes.",
  };

  for (const botId of knownBotIdsForTenant(tenantId)) {
    const collectionName = `bot-${botId}`;
    const defaults = {
      bob: "Bob coordination memory. Boundaries, routing, escalation, cross-bot authority limits, and coordinator behavior for tenant_0.",
      stacks:
        "Stacks media and social tone memory. Warmer friendlier tone, approachable Bitcoin-first media voice, avoid robotic copy and hype.",
      jennifer:
        "Jennifer editorial and research memory. Editorial discipline, evidence-minded framing, calm authority, and avoid marketing tone.",
      steve:
        "Steve engineering memory. Pragmatic implementation, small reviewable changes, migration safety, and avoid unnecessary rewrites.",
      number5:
        "Number5 business and operations memory. Business framing, operational thinking, structured proposals, and clear assumptions.",
    };
    contexts[collectionName] =
      defaults[botId] || `${botId} bot-private tenant_0 memory for role guidance and durable preferences.`;
  }

  return contexts;
}

function ensureCollectionContexts(tenantId, collections) {
  const contexts = desiredContextsForTenant(tenantId);

  for (const collection of collections) {
    const target = `qmd://${collection.name}/`;
    const summary = contexts[collection.name];
    if (!summary) {
      continue;
    }

    try {
      runQmd(tenantId, ["context", "add", target, summary]);
    } catch (error) {
      const stderr = String(error && error.stderr ? error.stderr : "");
      if (!/already exists|already has context|duplicate/i.test(stderr)) {
        throw new Error(
          `failed to add qmd context for ${collection.name}: ${stderr || error.message}`,
        );
      }
    }
  }
}

function ensureCollections(tenantId) {
  const collections = tenantCollections(tenantId);
  if (collections.length === 0) {
    throw new Error(`no memory collections found for tenant ${tenantId}`);
  }

  for (const collection of collections) {
    try {
      runQmd(tenantId, ["collection", "add", collection.dir, "--name", collection.name]);
    } catch (error) {
      const stderr = error && error.stderr ? String(error.stderr) : "";
      if (!/already exists/i.test(stderr)) {
        throw new Error(
          `failed to register qmd collection ${collection.name}: ${stderr || error.message}`,
        );
      }
    }
  }

  ensureCollectionContexts(tenantId, collections);
  return collections;
}

function parseJsonOrText(output) {
  try {
    return JSON.parse(output);
  } catch (_error) {
    return output.trim();
  }
}

function uniqueQueries(queryText) {
  const variants = [];
  const seen = new Set();
  const isDigitsOnly = (value) =>
    [...String(value || "")].every((ch) => ch >= "0" && ch <= "9");

  function addVariant(value) {
    const normalized = String(value || "").trim().split(" ").filter(Boolean).join(" ");
    if (!normalized || seen.has(normalized)) {
      return;
    }
    seen.add(normalized);
    variants.push(normalized);
  }

  addVariant(queryText);
  const commaFree = String(queryText || "").replace(/(?<=\\d),(?=\\d)/g, "");
  addVariant(commaFree);

  function humanizeDigits(digits) {
    const value = Number(digits);
    if (!Number.isFinite(value) || value < 1000) {
      return null;
    }

    const scales = [
      { threshold: 1000000000, suffix: "billion" },
      { threshold: 1000000, suffix: "million" },
      { threshold: 1000, suffix: "thousand" },
    ];

    for (const scale of scales) {
      if (value >= scale.threshold) {
        const scaled = value / scale.threshold;
        const rounded = Number(scaled.toFixed(scaled >= 100 ? 0 : scaled >= 10 ? 1 : 2));
        return String(rounded) + " " + scale.suffix;
      }
    }

    return null;
  }

  const humanizedParts = String(queryText || "").split(" ").map((part) => {
    const match = part.match(/^([^0-9,]*)([0-9][0-9,]*)([^0-9,]*)$/);
    if (!match) {
      return part;
    }
    const prefix = match[1];
    const bare = match[2];
    const suffix = match[3];
    if (!bare.includes(",")) {
      return part;
    }
    const digits = bare.split(",").join("");
    if (!isDigitsOnly(digits)) {
      return part;
    }
    const humanized = humanizeDigits(digits);
    if (!humanized) {
      return part;
    }
    return prefix + humanized + suffix;
  });
  addVariant(humanizedParts.join(" "));

  return variants;
}

function mergeResultsByDoc(queries, resultsByQuery) {
  const merged = [];
  const seen = new Set();

  for (const query of queries) {
    for (const item of resultsByQuery.get(query) || []) {
      const key = String(item.docid || "") + "|" + String(item.file || "");
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      merged.push(item);
    }
  }

  return merged;
}

function commandStatus(tenantId) {
  const collections = ensureCollections(tenantId);
  const output = runQmd(tenantId, ["status", "--json"]);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        retrievalRoot: retrievalRoot(tenantId),
        collections: collections.map((collection) => collection.name),
        status: parseJsonOrText(output),
      },
      null,
      2,
    ),
  );
}

function commandRebuild(tenantId, args) {
  const doEmbed = args.includes("--embed");
  const collections = ensureCollections(tenantId);
  const update = parseJsonOrText(runQmd(tenantId, ["update", "--json"]));
  const embed = doEmbed ? parseJsonOrText(runQmd(tenantId, ["embed", "--json"])) : null;

  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        retrievalRoot: retrievalRoot(tenantId),
        collections: collections.map((collection) => collection.name),
        update,
        embed,
      },
      null,
      2,
    ),
  );
}

function commandQuery(tenantId, botId, queryText) {
  ensureCollections(tenantId);
  const allowedCollections = allowedCollectionsForBot(tenantId, botId);
  const queryVariants = uniqueQueries(queryText);
  const resultsByQuery = new Map();

  for (const queryVariant of queryVariants) {
    const args = ["search", queryVariant, "--json", "-n", "5"];
    for (const collection of allowedCollections) {
      args.push("-c", collection);
    }
    const parsed = parseJsonOrText(runQmd(tenantId, args));
    resultsByQuery.set(queryVariant, Array.isArray(parsed) ? parsed : []);
  }

  const results = mergeResultsByDoc(queryVariants, resultsByQuery);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        botId,
        query: queryText,
        queryVariants,
        allowedCollections,
        retrievalRoot: retrievalRoot(tenantId),
        results,
      },
      null,
      2,
    ),
  );
}

function main() {
  const [, , command, ...args] = process.argv;

  if (!command) {
    usage();
    process.exit(1);
  }

  if (command === "status") {
    const [tenantId] = args;
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandStatus(tenantId);
    return;
  }

  if (command === "rebuild") {
    const [tenantId, ...rest] = args;
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandRebuild(tenantId, rest);
    return;
  }

  if (command === "query") {
    const [tenantId, botId, ...queryParts] = args;
    if (!tenantId || !botId || queryParts.length === 0) {
      usage();
      process.exit(1);
    }
    commandQuery(tenantId, botId, queryParts.join(" "));
    return;
  }

  usage();
  process.exit(1);
}

try {
  main();
} catch (error) {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(detail);
  process.exit(1);
}
EOF

  chmod 0755 "$OPENCLAW_QMD_WRAPPER"
}

write_transcript_importer() {
  cat >"$OPENCLAW_TRANSCRIPT_IMPORTER" <<EOF
#!/usr/bin/env node

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const DEFAULT_FEED_URL = process.env.CLAWBOT_PODCAST_RSS_FEED || ${OPENCLAW_PODCAST_RSS_FEED@Q};

function usage() {
  console.error(
    [
      "usage:",
      "  clawbot-import-podcast-transcripts import-dir <tenant-id> <input-dir>",
      "  clawbot-import-podcast-transcripts fetch-feed <tenant-id> [feed-url] [--limit N]",
    ].join("\\n"),
  );
}

function tenantTranscriptRoot(tenantId) {
  return "/opt/clawbot/tenants/" + tenantId + "/memory/sources/transcripts";
}

function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "transcript";
}

function normalizeTranscriptBody(raw) {
  const text = String(raw || "").replace(/\\r\\n/g, "\\n");
  if (/<(?:cite|time|p)\\b/i.test(text)) {
    return normalizePodcastHtmlTranscript(text);
  }

  const lines = text.split("\\n").map((line) => line.trimEnd());

  const out = [];
  let previousBlank = false;

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      if (!previousBlank) {
        out.push("");
      }
      previousBlank = true;
      continue;
    }
    previousBlank = false;
    out.push(trimmed);
  }

  return out.join("\\n").trim() + "\\n";
}

function normalizePodcastHtmlTranscript(raw) {
  const lines = [];
  let currentSpeaker = "";
  let currentTime = "";
  const tokenRegex = /<cite>([\\s\\S]*?)<\\/cite>|<time>([\\s\\S]*?)<\\/time>|<p>([\\s\\S]*?)<\\/p>/gi;

  for (const match of String(raw || "").matchAll(tokenRegex)) {
    if (match[1] !== undefined) {
      currentSpeaker = decodeXml(match[1]).replace(/:\\s*$/, "").trim();
      continue;
    }

    if (match[2] !== undefined) {
      currentTime = decodeXml(match[2]).trim();
      continue;
    }

    if (match[3] !== undefined) {
      const text = decodeXml(match[3])
        .replace(/<[^>]+>/g, " ")
        .replace(/\\s+/g, " ")
        .trim();
      if (!text) {
        continue;
      }
      const prefix = currentTime ? "[" + currentTime + "] " : "";
      const speaker = currentSpeaker ? currentSpeaker + ": " : "";
      lines.push((prefix + speaker + text).trim());
    }
  }

  return lines.join("\\n").trim() + "\\n";
}

function decodeXml(value) {
  return String(value || "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function sanitizeTitle(value) {
  return decodeXml(String(value || "").replace(/<!\\[CDATA\\[|\\]\\]>/g, "")).trim();
}

function deriveTitle(filePath, body) {
  const firstLine = body.split("\\n").find((line) => line.trim());
  if (firstLine && firstLine.length <= 120) {
    return firstLine.replace(/^\\[[^\\]]+\\]\\s*/, "").slice(0, 120);
  }
  return path.basename(filePath, path.extname(filePath));
}

function extractHeaderValue(raw, label) {
  return sanitizeTitle(raw.match(new RegExp("^" + label + ":\\\\s*(.+)$", "mi"))?.[1] || "");
}

function toIsoDate(value) {
  if (!value) {
    return "";
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString();
}

function parseEpisodeNumber(title) {
  const match = String(title || "").match(/^(\\d+)\\b/);
  return match ? Number(match[1]) : null;
}

function cleanUrl(value) {
  const match = String(value || "").match(/https?:\\/\\/[^\\s\"'<>()]+/);
  return match ? match[0] : "";
}

function canonicalEpisodeUrl(episodeNumber, fallbackUrl) {
  if (episodeNumber !== null) {
    return "https://satoshis-plebs.com/episodes/episode-" + episodeNumber;
  }
  return cleanUrl(fallbackUrl);
}

function parseSpeakers(body) {
  const speakers = [];
  const seen = new Set();
  const knownHosts = new Set(["McIntosh", "Kenshin"]);

  for (const line of String(body || "").split("\\n")) {
    const speaker = line.match(/^\\[[^\\]]+\\]\\s+([^:]+):/)?.[1]?.trim();
    if (!speaker || seen.has(speaker)) {
      continue;
    }
    seen.add(speaker);
    speakers.push(speaker);
  }

  return {
    speakers,
    hosts: speakers.filter((speaker) => knownHosts.has(speaker)),
    guests: speakers.filter((speaker) => !knownHosts.has(speaker)),
  };
}

function parseNumber(value) {
  const cleaned = String(value || "").replace(/,/g, "");
  const parsed = Number(cleaned);
  return Number.isFinite(parsed) ? parsed : null;
}

function extractTranscriptMetadata(raw, body, fallbackTitle) {
  const title = extractHeaderValue(raw, "Title") || fallbackTitle;
  const publishedAt = toIsoDate(extractHeaderValue(raw, "Published"));
  const episodeNumber = parseEpisodeNumber(title);
  const transcriptUrl = cleanUrl(extractHeaderValue(raw, "Transcript URL"));
  const episodeUrl = canonicalEpisodeUrl(
    episodeNumber,
    extractHeaderValue(raw, "Episode URL"),
  );
  const { speakers, hosts, guests } = parseSpeakers(body);

  const blockHeight =
    parseNumber(body.match(/block heights?[^0-9]{0,40}([0-9][0-9,]{4,})/i)?.[1]) ||
    parseNumber(body.match(/\\b(9[0-9]{2},?[0-9]{3})\\b/)?.[1]);

  const bitcoinPriceUsd =
    parseNumber(body.match(/our price[^0-9]{0,40}([0-9][0-9,]{3,}(?:\\.\\d+)?)/i)?.[1]) ||
    parseNumber(body.match(/price[^0-9]{0,20}([0-9][0-9,]{3,}(?:\\.\\d+)?)\\s+US\\b/i)?.[1]);

  const bitcoinPriceEur =
    parseNumber(
      body.match(/What about.*?\\n\\[[^\\]]+\\]\\s+[^:]+:\\s+([0-9][0-9,]{3,}(?:\\.\\d+)?)\\./is)?.[1],
    ) ||
    parseNumber(
      body.match(/How many kroner\\?.*?euros times 11.*?([0-9][0-9,]{3,}(?:\\.\\d+)?)/is)?.[1],
    ) ||
    parseNumber(body.match(/([0-9][0-9,]{3,}(?:\\.\\d+)?)\\s+euros?\\b/i)?.[1]) ||
    parseNumber(body.match(/price[^0-9]{0,20}([0-9][0-9,]{3,}(?:\\.\\d+)?)\\s+EUR\\b/i)?.[1]);

  const musicMatch =
    body.match(/This week's music.*?It's\\s+(.+?)\\s+by\\s+(.+?)\\./is) ||
    body.match(/music.*?is\\s+(.+?)\\s+by\\s+(.+?)\\./is);

  return {
    title,
    episodeNumber,
    publishedAt,
    transcriptUrl,
    episodeUrl,
    speakers,
    hosts,
    guests,
    blockHeight,
    bitcoinPriceUsd,
    bitcoinPriceEur,
    musicTitle: musicMatch?.[1]?.trim() || "",
    musicArtist: musicMatch?.[2]?.trim() || "",
  };
}

function frontmatter({
  id,
  tenantId,
  title,
  sourceFile,
  episodeNumber,
  publishedAt,
  transcriptUrl,
  episodeUrl,
  speakers,
  hosts,
  guests,
  blockHeight,
  bitcoinPriceUsd,
  bitcoinPriceEur,
  musicTitle,
  musicArtist,
}) {
  const lines = [
    "---",
    "id: " + id,
    "tenant_id: " + tenantId,
    "scope: tenant/" + tenantId + "/source/transcripts",
    "type: transcript",
    "status: active",
    "visibility: bot",
    "source: transcript_import",
    "tags:",
    "  - transcript",
    "  - podcast",
    "title: " + JSON.stringify(title),
    "source_file: " + JSON.stringify(sourceFile),
  ];

  if (episodeNumber !== null) {
    lines.push("episode_number: " + episodeNumber);
  }
  if (publishedAt) {
    lines.push("published_at: " + JSON.stringify(publishedAt));
  }
  if (episodeUrl) {
    lines.push("episode_url: " + JSON.stringify(episodeUrl));
  }
  if (transcriptUrl) {
    lines.push("transcript_url: " + JSON.stringify(transcriptUrl));
  }
  if (speakers.length > 0) {
    lines.push("speakers:");
    for (const speaker of speakers) {
      lines.push("  - " + JSON.stringify(speaker));
    }
  }
  if (hosts.length > 0) {
    lines.push("hosts:");
    for (const host of hosts) {
      lines.push("  - " + JSON.stringify(host));
    }
  }
  if (guests.length > 0) {
    lines.push("guests:");
    for (const guest of guests) {
      lines.push("  - " + JSON.stringify(guest));
    }
  }
  if (blockHeight !== null) {
    lines.push("block_height: " + blockHeight);
  }
  if (bitcoinPriceUsd !== null) {
    lines.push("bitcoin_price_usd: " + bitcoinPriceUsd);
  }
  if (bitcoinPriceEur !== null) {
    lines.push("bitcoin_price_eur: " + bitcoinPriceEur);
  }
  if (musicTitle) {
    lines.push("music_title: " + JSON.stringify(musicTitle));
  }
  if (musicArtist) {
    lines.push("music_artist: " + JSON.stringify(musicArtist));
  }

  lines.push("---", "");
  return lines.join("\\n");
}

function writeTranscriptChunk({
  outputDir,
  tenantId,
  baseId,
  metadata,
  sourceFile,
  chunkIndex,
  lines,
}) {
  if (!lines.length) {
    return null;
  }
  const id = baseId + "-chunk-" + String(chunkIndex).padStart(3, "0");
  const targetPath = path.join(outputDir, id + ".md");
  fs.writeFileSync(
    targetPath,
    frontmatter({
      id,
      tenantId,
      title: metadata.title + " (chunk " + chunkIndex + ")",
      sourceFile,
      episodeNumber: metadata.episodeNumber,
      publishedAt: metadata.publishedAt,
      transcriptUrl: metadata.transcriptUrl,
      episodeUrl: metadata.episodeUrl,
      speakers: metadata.speakers,
      hosts: metadata.hosts,
      guests: metadata.guests,
      blockHeight: metadata.blockHeight,
      bitcoinPriceUsd: metadata.bitcoinPriceUsd,
      bitcoinPriceEur: metadata.bitcoinPriceEur,
      musicTitle: metadata.musicTitle,
      musicArtist: metadata.musicArtist,
    }) + lines.join("\\n").trim() + "\\n",
    "utf8",
  );
  return targetPath;
}

function chunkTranscript(body) {
  const lines = body
    .split("\\n")
    .map((line) => line.trim())
    .filter(Boolean);
  const chunks = [];
  let current = [];

  for (const line of lines) {
    current.push(line);
    if (current.length >= 80) {
      chunks.push(current);
      current = [];
    }
  }

  if (current.length > 0) {
    chunks.push(current);
  }

  return chunks;
}

function importDir(tenantId, inputDir) {
  const outputDir = tenantTranscriptRoot(tenantId);
  fs.mkdirSync(outputDir, { recursive: true });

  const files = fs
    .readdirSync(inputDir, { withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(inputDir, entry.name))
    .filter((filePath) => /\\.(txt|md)\$/i.test(filePath))
    .sort();

  const imported = [];

  for (const filePath of files) {
    const raw = fs.readFileSync(filePath, "utf8");
    const body = normalizeTranscriptBody(raw);
    const fallbackTitle =
      sanitizeTitle(raw.match(/^Title:\\s*(.+)$/m)?.[1] || "") ||
      deriveTitle(filePath, body);
    const metadata = extractTranscriptMetadata(raw, body, fallbackTitle);
    const baseId = slugify(path.basename(filePath, path.extname(filePath)));
    const chunks = chunkTranscript(body);
    for (let i = 0; i < chunks.length; i += 1) {
      const targetPath = writeTranscriptChunk({
        outputDir,
        tenantId,
        baseId,
        metadata,
        sourceFile: path.basename(filePath),
        chunkIndex: i + 1,
        lines: chunks[i],
      });
      if (targetPath) {
        imported.push(targetPath);
      }
    }
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        inputDir,
        outputDir,
        imported,
      },
      null,
      2,
    ),
  );
}

function parseFeed(feedXml) {
  const items = [];
  const itemRegex = /<item\\b[\\s\\S]*?<\\/item>/gi;
  const transcriptRegex = /<(?:podcast:)?transcript\\b([^>]*)\\/?>/gi;

  for (const itemMatch of String(feedXml || "").matchAll(itemRegex)) {
    const itemXml = itemMatch[0];
    const title = sanitizeTitle(itemXml.match(/<title>([\\s\\S]*?)<\\/title>/i)?.[1] || "");
    const pubDate = sanitizeTitle(itemXml.match(/<pubDate>([\\s\\S]*?)<\\/pubDate>/i)?.[1] || "");
    const guid = sanitizeTitle(itemXml.match(/<guid[^>]*>([\\s\\S]*?)<\\/guid>/i)?.[1] || "");
    const link = sanitizeTitle(itemXml.match(/<link>([\\s\\S]*?)<\\/link>/i)?.[1] || "");
    const transcripts = [];

    for (const transcriptMatch of itemXml.matchAll(transcriptRegex)) {
      const attrs = transcriptMatch[1] || "";
      const url = attrs.match(/\\burl=\"([^\"]+)\"/i)?.[1] || attrs.match(/\\burl='([^']+)'/i)?.[1] || "";
      const type = attrs.match(/\\btype=\"([^\"]+)\"/i)?.[1] || attrs.match(/\\btype='([^']+)'/i)?.[1] || "";
      const language = attrs.match(/\\blanguage=\"([^\"]+)\"/i)?.[1] || attrs.match(/\\blanguage='([^']+)'/i)?.[1] || "";
      if (url) {
        transcripts.push({ url: decodeXml(url), type: decodeXml(type), language: decodeXml(language) });
      }
    }

    if (transcripts.length > 0) {
      items.push({ title, pubDate, guid, link, transcripts });
    }
  }

  return items;
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: {
      "User-Agent": "clawbot-transcript-import/1.0",
      "Accept": "application/rss+xml, application/xml, text/plain, text/vtt, */*",
    },
  });
  if (!response.ok) {
    throw new Error(
      "fetch failed for " + url + ": " + response.status + " " + response.statusText,
    );
  }
  return await response.text();
}

async function commandFetchFeed(tenantId, feedUrl, limit) {
  const xml = await fetchText(feedUrl);
  const items = parseFeed(xml);
  const selected = items.slice(0, limit > 0 ? limit : items.length);
  const tempDir = fs.mkdtempSync(
    path.join(os.tmpdir(), "clawbot-transcripts-" + tenantId + "-"),
  );

  for (let index = 0; index < selected.length; index += 1) {
    const item = selected[index];
    const transcript = item.transcripts.find((entry) => !entry.language || entry.language.toLowerCase().startsWith("en")) || item.transcripts[0];
    const rawText = await fetchText(transcript.url);
    const fileBase = slugify(item.guid || item.title || "episode-" + (index + 1));
    const sourcePath = path.join(tempDir, fileBase + ".txt");
    const header = [
      item.title ? "Title: " + item.title : "",
      item.pubDate ? "Published: " + item.pubDate : "",
      item.link ? "Episode URL: " + item.link : "",
      transcript.url ? "Transcript URL: " + transcript.url : "",
      "",
    ]
      .filter(Boolean)
      .join("\\n");
    fs.writeFileSync(sourcePath, header + rawText, "utf8");
  }

  importDir(tenantId, tempDir);
}

async function main() {
  const [, , command, tenantId, ...rest] = process.argv;

  if (!tenantId) {
    usage();
    process.exit(1);
  }

  if (command === "import-dir") {
    const [inputDir] = rest;
    if (!inputDir) {
      usage();
      process.exit(1);
    }
    importDir(tenantId, inputDir);
    return;
  }

  if (command === "fetch-feed") {
    let feedUrl = DEFAULT_FEED_URL;
    let limit = 25;

    for (let i = 0; i < rest.length; i += 1) {
      const arg = rest[i];
      if (arg === "--limit") {
        limit = Number(rest[i + 1] || "25");
        i += 1;
        continue;
      }
      if (!arg.startsWith("--")) {
        feedUrl = arg;
      }
    }

    await commandFetchFeed(tenantId, feedUrl, limit);
    return;
  }

  usage();
  process.exit(1);
}

main().catch((error) => {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(detail);
  process.exit(1);
});
EOF

  chmod 0755 "$OPENCLAW_TRANSCRIPT_IMPORTER"
}

write_observation_review_tool() {
  cat >"$OPENCLAW_OBSERVATION_REVIEW_TOOL" <<'EOF'
#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

function usage() {
  console.error(
    [
      "usage:",
      "  clawbot-observation-review list <tenant-id> [--bot <bot-id>] [--status <status>]",
      "  clawbot-observation-review show <tenant-id> <observation-id>",
      "  clawbot-observation-review reject <tenant-id> <observation-id>",
      "  clawbot-observation-review promote <tenant-id> <observation-id>",
    ].join("\n"),
  );
}

function tenantRoot(tenantId) {
  return "/opt/clawbot/tenants/" + tenantId;
}

function observationsRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "observations");
}

function canonicalRoot(tenantId) {
  return path.join(tenantRoot(tenantId), "memory", "canonical");
}

function nowIso() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
}

function walkMarkdownFiles(rootDir) {
  const out = [];
  if (!fs.existsSync(rootDir)) {
    return out;
  }
  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    const target = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      out.push(...walkMarkdownFiles(target));
      continue;
    }
    if (entry.isFile() && target.endsWith(".md")) {
      out.push(target);
    }
  }
  return out.sort();
}

function parseScalar(value) {
  const trimmed = String(value || "").trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    try {
      return JSON.parse(trimmed);
    } catch (_error) {
      return trimmed.slice(1, -1);
    }
  }
  return trimmed;
}

function parseFrontmatter(text) {
  const normalized = String(text || "").replace(/\r\n/g, "\n");
  if (!normalized.startsWith("---\n")) {
    return { meta: {}, body: normalized.trim() };
  }
  const end = normalized.indexOf("\n---\n", 4);
  if (end === -1) {
    return { meta: {}, body: normalized.trim() };
  }

  const block = normalized.slice(4, end);
  const body = normalized.slice(end + 5).replace(/^\n+/, "");
  const meta = {};
  let currentListKey = null;

  for (const line of block.split("\n")) {
    if (!line.trim()) {
      continue;
    }
    const listMatch = line.match(/^\s*-\s+(.*)$/);
    if (listMatch && currentListKey) {
      meta[currentListKey].push(parseScalar(listMatch[1]));
      continue;
    }
    const fieldMatch = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!fieldMatch) {
      currentListKey = null;
      continue;
    }
    const key = fieldMatch[1];
    const rawValue = fieldMatch[2];
    if (rawValue === "") {
      meta[key] = [];
      currentListKey = key;
      continue;
    }
    meta[key] = parseScalar(rawValue);
    currentListKey = null;
  }

  return { meta, body: body.trim() };
}

function stringifyScalar(value) {
  return typeof value === "string" ? JSON.stringify(value) : String(value);
}

function stringifyFrontmatter(meta, body) {
  const lines = ["---"];
  for (const entry of Object.entries(meta)) {
    const key = entry[0];
    const value = entry[1];
    if (value === undefined || value === null || value === "") {
      continue;
    }
    if (Array.isArray(value)) {
      lines.push(key + ":");
      for (const item of value) {
        lines.push("  - " + stringifyScalar(item));
      }
      continue;
    }
    lines.push(key + ": " + stringifyScalar(value));
  }
  lines.push("---", "", String(body || "").trim(), "");
  return lines.join("\n");
}

function loadObservationFile(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  const parsed = parseFrontmatter(text);
  return { path: filePath, meta: parsed.meta, body: parsed.body };
}

function allObservations(tenantId) {
  return walkMarkdownFiles(observationsRoot(tenantId)).map(loadObservationFile);
}

function findObservation(tenantId, observationId) {
  const match = allObservations(tenantId).find(
    (item) => String(item.meta.id || "") === observationId,
  );
  if (!match) {
    throw new Error("observation not found: " + observationId);
  }
  return match;
}

function writeObservation(item) {
  fs.writeFileSync(item.path, stringifyFrontmatter(item.meta, item.body), "utf8");
}

function canonicalTargetForObservation(tenantId, item) {
  const botId = String(item.meta.bot_id || "").trim();
  if (!botId) {
    throw new Error("observation " + String(item.meta.id || item.path) + " is missing bot_id");
  }
  const canonicalId = String(item.meta.id || "").replace(/^obs-/, "mem-").trim();
  const targetDir = path.join(canonicalRoot(tenantId), "bots", botId);
  const targetPath = path.join(targetDir, canonicalId + ".md");
  return { canonicalId, targetDir, targetPath };
}

function writeCanonicalFromObservation(tenantId, item) {
  const target = canonicalTargetForObservation(tenantId, item);
  fs.mkdirSync(target.targetDir, { recursive: true });
  if (fs.existsSync(target.targetPath)) {
    throw new Error(
      "canonical memory already exists for observation " +
        String(item.meta.id || "") +
        ": " +
        target.targetPath,
    );
  }

  const createdAt = String(item.meta.created_at || nowIso());
  const updatedAt = nowIso();
  const tags = Array.isArray(item.meta.tags)
    ? [...new Set([...item.meta.tags, "promoted-observation"])]
    : ["promoted-observation"];

  const canonicalMeta = {
    id: target.canonicalId,
    tenant_id: tenantId,
    scope: item.meta.scope || "tenant/" + tenantId + "/bot/" + item.meta.bot_id,
    bot_id: item.meta.bot_id,
    type: "note",
    status: "active",
    visibility: item.meta.visibility || "bot",
    source: "observation_promotion",
    promoted_from: item.meta.id,
    created_at: createdAt,
    updated_at: updatedAt,
    tags,
  };

  fs.writeFileSync(
    target.targetPath,
    stringifyFrontmatter(canonicalMeta, item.body),
    "utf8",
  );
  return { canonicalId: target.canonicalId, targetPath: target.targetPath, updatedAt };
}

function commandList(tenantId, args) {
  let botId = "";
  let status = "";
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === "--bot") {
      botId = String(args[i + 1] || "").trim();
      i += 1;
      continue;
    }
    if (args[i] === "--status") {
      status = String(args[i + 1] || "").trim();
      i += 1;
    }
  }

  const observations = allObservations(tenantId)
    .filter((item) => !botId || String(item.meta.bot_id || "") === botId)
    .filter((item) => !status || String(item.meta.status || "") === status)
    .map((item) => ({
      id: item.meta.id || "",
      bot_id: item.meta.bot_id || "",
      status: item.meta.status || "",
      created_at: item.meta.created_at || "",
      updated_at: item.meta.updated_at || "",
      path: item.path,
      body_preview: item.body.split("\n")[0].slice(0, 160),
    }));

  console.log(JSON.stringify({ ok: true, tenantId, observations }, null, 2));
}

function commandShow(tenantId, observationId) {
  const item = findObservation(tenantId, observationId);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        observation: {
          path: item.path,
          meta: item.meta,
          body: item.body,
        },
      },
      null,
      2,
    ),
  );
}

function commandReject(tenantId, observationId) {
  const item = findObservation(tenantId, observationId);
  item.meta.status = "rejected";
  item.meta.updated_at = nowIso();
  writeObservation(item);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        observation: {
          id: item.meta.id,
          status: item.meta.status,
          path: item.path,
        },
      },
      null,
      2,
    ),
  );
}

function commandPromote(tenantId, observationId) {
  const item = findObservation(tenantId, observationId);
  const promotion = writeCanonicalFromObservation(tenantId, item);
  item.meta.status = "accepted";
  item.meta.updated_at = promotion.updatedAt;
  item.meta.promoted_to = promotion.canonicalId;
  item.meta.promoted_path = promotion.targetPath;
  writeObservation(item);
  console.log(
    JSON.stringify(
      {
        ok: true,
        tenantId,
        observation: {
          id: item.meta.id,
          status: item.meta.status,
          path: item.path,
          promoted_to: promotion.canonicalId,
          promoted_path: promotion.targetPath,
        },
      },
      null,
      2,
    ),
  );
}

function main() {
  const [, , command, ...args] = process.argv;
  if (!command) {
    usage();
    process.exit(1);
  }

  if (command === "list") {
    const tenantId = args[0];
    const rest = args.slice(1);
    if (!tenantId) {
      usage();
      process.exit(1);
    }
    commandList(tenantId, rest);
    return;
  }

  if (command === "show") {
    const tenantId = args[0];
    const observationId = args[1];
    if (!tenantId || !observationId) {
      usage();
      process.exit(1);
    }
    commandShow(tenantId, observationId);
    return;
  }

  if (command === "reject") {
    const tenantId = args[0];
    const observationId = args[1];
    if (!tenantId || !observationId) {
      usage();
      process.exit(1);
    }
    commandReject(tenantId, observationId);
    return;
  }

  if (command === "promote") {
    const tenantId = args[0];
    const observationId = args[1];
    if (!tenantId || !observationId) {
      usage();
      process.exit(1);
    }
    commandPromote(tenantId, observationId);
    return;
  }

  usage();
  process.exit(1);
}

try {
  main();
} catch (error) {
  const detail = error instanceof Error ? error.message : String(error);
  console.error(detail);
  process.exit(1);
}
EOF

  chmod 0755 "$OPENCLAW_OBSERVATION_REVIEW_TOOL"
}

install_qmd_cli() {
  ensure_qmd_node_runtime
  npm install -g "$OPENCLAW_QMD_NPM_PACKAGE"
  command -v qmd >/dev/null 2>&1
  write_qmd_tenant_wrapper
  write_transcript_importer
  write_observation_review_tool
}

configure_ufw() {
  if ! command -v ufw >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
  fi

  if grep -q '^IPV6=' /etc/default/ufw; then
    sed -i 's/^IPV6=.*/IPV6=no/' /etc/default/ufw
  else
    echo "IPV6=no" >> /etc/default/ufw
  fi
  systemctl reload ufw >/dev/null 2>&1 || true

  if ! ufw status 2>/dev/null | grep -q "^Status: active"; then
    : # skip policy check until enabled
  else
    if ! ufw status verbose | grep -q "Default: deny (incoming)"; then
      ufw default deny incoming
    fi
    if ! ufw status verbose | grep -q "Default: allow (outgoing)"; then
      ufw default allow outgoing
    fi
  fi

  if ! ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw --force enable
    if ! ufw status verbose | grep -q "Default: deny (incoming)"; then
      ufw default deny incoming
    fi
    if ! ufw status verbose | grep -q "Default: allow (outgoing)"; then
      ufw default allow outgoing
    fi
  fi

  if ! ufw status | grep -qE '(^|[[:space:]])22/tcp([[:space:]]|$)'; then
    ufw limit 22/tcp
  fi
  if ! ufw status | grep -qE '(^|[[:space:]])80/tcp([[:space:]]|$)'; then
    ufw allow 80/tcp
  fi
  if ! ufw status | grep -qE '(^|[[:space:]])443/tcp([[:space:]]|$)'; then
    ufw allow 443/tcp
  fi

  if ! ufw status verbose | grep -q "Logging: on (low)"; then
    ufw logging on
  fi
}

enable_openclaw_service() {
  enable_user_service openclaw.service
}

enable_user_service() {
  local service_name="$1"
  local output
  local rc

  set +e
  output="$(run_as_openclaw_from_tmp systemctl --user enable "$service_name" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi

  if [[ "$output" == *"transient or generated"* ]]; then
    log "${service_name} is a generated quadlet unit; enable is not required."
    return 0
  fi

  echo "$output"
  return "$rc"
}

run_as_openclaw() {
  local openclaw_uid
  openclaw_uid="$(id -u "$OPENCLAW_USER")"

  if [[ "$(id -u)" -eq "$openclaw_uid" ]]; then
    XDG_RUNTIME_DIR="/run/user/$openclaw_uid" HOME="/home/$OPENCLAW_USER" "$@"
    return 0
  fi

  if command -v runuser >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    if runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" "$@"; then
      return 0
    fi
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" "$@"
}

run_as_openclaw_from_tmp() {
  local openclaw_uid
  openclaw_uid="$(id -u "$OPENCLAW_USER")"

  if [[ "$(id -u)" -eq "$openclaw_uid" ]]; then
    (
      cd /tmp
      XDG_RUNTIME_DIR="/run/user/$openclaw_uid" HOME="/home/$OPENCLAW_USER" "$@"
    )
    return 0
  fi

  if command -v runuser >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    if runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" \
      sh -c 'cd /tmp && exec "$@"' sh "$@"; then
      return 0
    fi
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" \
    sh -c 'cd /tmp && exec "$@"' sh "$@"
}

run_as_openclaw_in_dir() {
  local target_dir="$1"
  shift

  local openclaw_uid
  openclaw_uid="$(id -u "$OPENCLAW_USER")"

  if [[ "$(id -u)" -eq "$openclaw_uid" ]]; then
    (
      cd "$target_dir"
      XDG_RUNTIME_DIR="/run/user/$openclaw_uid" HOME="/home/$OPENCLAW_USER" "$@"
    )
    return 0
  fi

  if command -v runuser >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    if runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" \
      sh -c 'cd "$1" && shift && exec "$@"' sh "$target_dir" "$@"; then
      return 0
    fi
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" \
    sh -c 'cd "$1" && shift && exec "$@"' sh "$target_dir" "$@"
}

decode_template_to_file() {
  local target="$1"
  local template_b64="$2"

  if [[ -z "$template_b64" ]]; then
    return 1
  fi

  if printf '%s' "$template_b64" | base64 -d | gzip -dc > "$target"; then
    return 0
  fi

  return 1
}

write_openclaw_ctl() {
  cat >/usr/local/bin/openclaw-ctl <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
RUNTIME_DIR="/run/user/$OPENCLAW_UID"
OPENCLAW_AGENT_CONFIG_DIR="${OPENCLAW_AGENT_CONFIG_DIR:-/opt/clawbot/config/agent-config}"
AGENT_CONFIG_DIR="${OPENCLAW_AGENT_CONFIG_DIR}"

usage() {
  cat <<'USAGE'
usage: openclaw-ctl [command]

commands:
  status        show openclaw.service status
  ps            list podman containers
  restart       restart openclaw.service
  start         start openclaw.service
  stop          stop openclaw.service
  logs          tail openclaw logs (podman)
  journal       show service journal (user journal)
  health        run local gateway health request
  token         print OPENCLAW_GATEWAY_TOKEN file
  agents        list files under agent-config
  agent-config  print a specific agent config file (relative path required)
  help          print this help
USAGE
}

run_as_openclaw() {
  if [[ "$(id -un)" == "$OPENCLAW_USER" ]]; then
    XDG_RUNTIME_DIR="$RUNTIME_DIR" HOME="/home/$OPENCLAW_USER" "$@"
    return
  fi

  if command -v runuser >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=$RUNTIME_DIR" "HOME=/home/$OPENCLAW_USER" "$@" && return
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=$RUNTIME_DIR" "HOME=/home/$OPENCLAW_USER" "$@"
}

run_as_openclaw_from_tmp() {
  if [[ "$(id -un)" == "$OPENCLAW_USER" ]]; then
    (
      cd /tmp
      XDG_RUNTIME_DIR="$RUNTIME_DIR" HOME="/home/$OPENCLAW_USER" "$@"
    )
    return
  fi

  if command -v runuser >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
    runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=$RUNTIME_DIR" "HOME=/home/$OPENCLAW_USER" \
      sh -c 'cd /tmp && exec "$@"' sh "$@" && return
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=$RUNTIME_DIR" "HOME=/home/$OPENCLAW_USER" \
    sh -c 'cd /tmp && exec "$@"' sh "$@"
}

case "${1:-status}" in
  status)
    run_as_openclaw_from_tmp systemctl --user status openclaw.service --no-pager
    ;;
  ps)
    run_as_openclaw podman ps -a
    ;;
  restart)
    run_as_openclaw_from_tmp systemctl --user restart openclaw.service
    ;;
  start)
    run_as_openclaw_from_tmp systemctl --user start openclaw.service
    ;;
  stop)
    run_as_openclaw_from_tmp systemctl --user stop openclaw.service
    ;;
  logs)
    run_as_openclaw podman logs openclaw
    ;;
  journal)
    run_as_openclaw_from_tmp journalctl --user -u openclaw.service --no-pager
    ;;
  health)
    run_as_openclaw curl -s -I http://127.0.0.1:18789/
    ;;
  token)
    run_as_openclaw cat /opt/clawbot/config/.env
    ;;
  agents)
    run_as_openclaw find "$AGENT_CONFIG_DIR" -maxdepth 3 -type f | sort
    ;;
  agent-config)
    if [[ -z "${2:-}" ]]; then
      echo "agent-config requires a relative path under ${AGENT_CONFIG_DIR}" >&2
      exit 2
    fi
    agent_config_path="${2//\"/}"
    if [[ "$agent_config_path" == /* || "$agent_config_path" == *".."* ]]; then
      echo "agent-config path must be a relative path under ${AGENT_CONFIG_DIR} and must not contain traversal segments." >&2
      exit 2
    fi
    run_as_openclaw cat "$AGENT_CONFIG_DIR/$agent_config_path"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "unknown command: $1" >&2
    usage
    exit 2
  ;;
esac
EOF

  sed -i '1{$s/^\xEF\xBB\xBF//; /^$/d;}' /usr/local/bin/openclaw-ctl

  chmod 0755 /usr/local/bin/openclaw-ctl
}

build_openclaw_image_as_openclaw() {
  local image="$1"
  local repo_dir="$2"

  if run_as_openclaw podman image inspect "$image" >/dev/null 2>&1; then
    return 0
  fi

  run_as_openclaw_in_dir "$repo_dir" podman build -t "$image" -f Dockerfile .
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this as root (for example: sudo bash /usr/local/bin/openclaw-node-bootstrap-runner)" >&2
  exit 1
fi

mkdir -p /var/lib/clawbot
run_step "Wait for system boot" wait_for_system_boot 36 10
if ! id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  run_step "Create openclaw user" useradd --system --create-home --home-dir /home/"$OPENCLAW_USER" --shell /usr/sbin/nologin "$OPENCLAW_USER"
fi
OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
assert_opt_volume_mount
run_step "Prepare bootstrap directories" prepare_bootstrap_directories
run_step "Prepare root secret directories" prepare_root_secret_directories
run_step "Prepare tenant memory roots" configure_tenant_memory_roots
run_step "Install tenant QMD pilot tooling" install_qmd_cli
run_step "Ensure system swap" ensure_swap "$OPENCLAW_SWAP_SIZE_MB"
run_step "Initialize agent secret stores" ensure_agent_secret_stores
run_step "Install agent secret provider" write_agent_secret_provider
run_step "Install agent secret sudoers policy" write_agent_secret_sudoers
run_step "Configure nostr signer services" configure_nostr_signers
run_step "Configure memory services" configure_memory_services
run_step "Configure proposal services" configure_proposal_services
run_step "Prepare bootstrap runtime directory" prepare_runtime_config_directory
ensure_gateway_token

if [[ ! -d "$OPENCLAW_AGENT_CONFIG_DIR" ]]; then
  run_step "Prepare default agent config templates" prepare_default_agent_config_templates
fi

run_step "Sync private agent pack" sync_private_agent_pack

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/agent-fleet.yaml" ]]; then
  if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/agent-fleet.yaml" "$OPENCLAW_AGENT_FLEET_TEMPLATE_B64"; then
cat >"$OPENCLAW_AGENT_CONFIG_DIR/agent-fleet.yaml" <<'EOF'
orchestrator:
  role: generic-orchestrator
  aliases:
    - bob
    - bucket-of-bits
  objective: |
    Coordinate specialist agents and route requests based on user intent and
    operational context.
  escalation_rules:
    - only escalate to specialist agents when clear ownership boundaries exist
    - require explicit confirmation for destructive operations
    - keep audit trail for important state changes

specialists:
  - name: podcast_media
    role: media operations and podcast production
    primary_tasks:
      - content planning and scheduling
      - production runbook generation
      - media tooling workflow for recordings
      - social and announcement posting for new episodes
      - generate and prepare short clip assets for distribution
    token: podcast-media
  - name: research
    role: market and feature research
    primary_tasks:
      - external data gathering
      - competitive analysis
      - concise evidence-based recommendations
    token: research
  - name: engineering
    role: engineering implementation and platform support
    primary_tasks:
      - code design, review, and refinement
      - build and test support recommendations
      - automation and tooling improvements
    token: engineering
  - name: business
    display_name: Number 5
    role: business operations and process support (Number 5)
    primary_tasks:
      - process design and tracking
      - planning and prioritization
      - operational communication
    token: business
EOF
  fi

  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/agent-fleet.yaml"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/agent-fleet.yaml"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" ]]; then
  if [[ -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md" ]]; then
    run_step "Ensure podcast_media specialist alias" cp "$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md"
  elif [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" ]]; then
    if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" "$OPENCLAW_STACKS_TEMPLATE_B64"; then
      cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" <<'EOF'
# Specialist: podcast_media (Stacks)

## Mission

Make podcast operations repeatable and fast: planning → recording → post → publishing → promos.

## Scope

- Show operations workflows and runbooks
- Recording and post-production checklists
- Tooling workflow guidance (DAWs, editing, mastering, loudness, exports)
- Announcement templates and clip/highlight pipeline guidance

## Open-source first
Prefer open-source and self-hostable tools when feasible.
If recommending proprietary tooling, include an OSS alternative and tradeoffs.

## Constraints
- No infrastructure changes.
- Do not approve external dependencies or credentials.
- Do not publish externally without explicit confirmation.

## Output format
- Title
- Summary (2–4 lines)
- Checklist (grouped by phase)
- Tools/settings (only what matters)
- Risks + fallback
- Definition of done

## Escalate to Bob when
- Credentials/APIs are needed
- Any infrastructure or deployment changes are requested
- Copyright/legal questions go beyond basic safe guidance
EOF
    fi
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" ]]; then
  if [[ -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md" ]]; then
    run_step "Ensure research specialist alias" cp "$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md"
  elif [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" ]]; then
    if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" "$OPENCLAW_JENNIFER_TEMPLATE_B64"; then
      cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" <<'EOF'
# Specialist: research (Jennifer)

## Mission

Bring receipts, form opinions, and make decisions easier. Fast research, strong recommendations.

## Scope

- Evidence gathering (primary sources first)
- Comparisons and competitive analysis
- Decision matrices and recommendations
- Summaries that separate facts from opinion

## Open-source first
Prefer open-source/self-hostable options when feasible.
If proprietary is best, include an OSS alternative + tradeoffs.

## Output format
- What we know (with sources)
- What we don’t know (open questions)
- Options (pros/cons)
- Recommendation (justified)
- Confidence
- Next verification steps

## Escalate to Bob when
- High-stakes medical/legal/financial decisions
- Conflicting credible sources with high risk
- Requests for private/doxxing info
EOF
    fi
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" ]]; then
  if [[ -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md" ]]; then
    run_step "Ensure engineering specialist alias" cp "$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md"
  elif [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" ]]; then
    if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" "$OPENCLAW_STEVE_TEMPLATE_B64"; then
      cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" <<'EOF'
# Specialist: engineering (Steve)

## Mission

Solve engineering problems with elegant, simple, reliable solutions.
Prefer rollback-friendly changes and systems you can understand at 3am.

## Scope
- Implementation design/review
- Debugging and troubleshooting
- Automation/tooling design
- Containers/systemd/network issues
- Observability recommendations

## Open-source first
- Prefer OSS and open standards.
- If recommending proprietary tooling, include:
  1) why OSS isn’t sufficient
  2) an OSS alternative
  3) an exit plan

## Output format
- Model (how it works)
- Fix (commands / file edits)
- Verify
- Rollback

## Constraints
- Do not apply destructive changes without explicit confirmation.
- Do not rotate or expose secrets.
- Avoid unnecessary new frameworks
EOF
    fi
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md" ]]; then
  if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md" "$OPENCLAW_BUSINESS_TEMPLATE_B64"; then
  cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md" <<'EOF'
# Specialist: business

## Scope

- Turn ideas into operational process and execution plans.
- Define owners, milestones, and lightweight operating rhythms.
- Create practical SOPs and checklists for repeatable work.

## Constraints

- Avoid legal and HR policy commitments.
- Avoid publishing or external comms without confirmation.
EOF
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator/policy.md" ]]; then
  if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator/policy.md" "$OPENCLAW_ORCHESTRATOR_POLICY_TEMPLATE_B64"; then
    cat >"$OPENCLAW_AGENT_CONFIG_DIR/orchestrator/policy.md" <<'EOF'
# Orchestrator policy

## Purpose

The orchestrator is a coordination role, not a domain-specific implementation
specialist. It owns task routing and handoff, while keeping specialist roles
focused and accountable.

## Principles

1. Route to the minimal specialist needed for each request.
2. Preserve context and constraints in task handoff notes.
3. Never let a specialist perform actions outside its defined scope.
4. Ask for confirmation for actions that modify infrastructure or secrets.

## Default routing logic

- If request is creative workflow support for a show or media artifacts, route to `stacks`.
- If request is evidence gathering, fact checking, or comparison work, route to `jennifer`.
- If request is implementation-heavy or systems work, route to `steve`.
- Otherwise, keep handling in orchestrator context and ask for clarification.
EOF
  fi

  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator/policy.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator/policy.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md" ]]; then
  if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md" "$OPENCLAW_STACKS_TEMPLATE_B64"; then
  cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md" <<'EOF'
# Specialist: stacks

## Scope

- Build and maintain podcast show operations workflows.
- Manage media production tasks and checklists.
- Suggest run plans for recording, post-production, and episode ops.
- Own media announcement posts and social publishing workflows for new episode launches.
- Prepare short clip workflows from raw/weekly assets for distribution.
- Support on-air participation planning by drafting talking points and transitions for co-host sessions.

## Constraints

- No infrastructure changes.
- Do not approve external dependencies or credentials.
- Only propose high-confidence, low-risk operations by default.
EOF
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/stacks.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md" ]]; then
  if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md" "$OPENCLAW_JENNIFER_TEMPLATE_B64"; then
  cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md" <<'EOF'
# Specialist: jennifer

## Scope

- Gather evidence and evaluate alternatives.
- Summarize findings with sources and confidence.
- Produce concise recommendations and trade-offs.

## Constraints

- Keep recommendations scoped and avoid implementation details outside your domain.
- Report uncertainty and assumptions clearly.
EOF
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/jennifer.md"
fi

if [[ ! -f "$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md" ]]; then
  if ! decode_template_to_file "$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md" "$OPENCLAW_STEVE_TEMPLATE_B64"; then
  cat >"$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md" <<'EOF'
# Specialist: steve

## Scope

- Develop and review practical implementation details.
- Recommend safe, minimal engineering changes.
- Keep technical recommendations operational and testable.

## Constraints

- Do not change production systems directly without approval.
- Keep recommendations scoped to implementation safety and rollbackability.
EOF
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md"
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/steve.md"
fi

if [[ ! -f "/opt/clawbot/config/runtime/llm.yaml" ]]; then
  if ! decode_template_to_file "/opt/clawbot/config/runtime/llm.yaml" "$OPENCLAW_LLM_TEMPLATE_B64"; then
  cat >/opt/clawbot/config/runtime/llm.yaml <<'EOF'
llm:
  provider: openai_compatible
  base_url: https://openrouter.ai/api/v1

  defaults:
    model: moonshotai/kimi-k2.5
    temperature: 0.3
    max_output_tokens: 1600
    timeout_seconds: 60

  per_agent_overrides:
    orchestrator:
      max_output_tokens: 900
      temperature: 0.2

    research:
      max_output_tokens: 1600
      temperature: 0.4

    engineering:
      max_output_tokens: 4500
      temperature: 0.2

    business:
      max_output_tokens: 1400
      temperature: 0.3

    podcast_media:
      max_output_tokens: 2200
      temperature: 0.3
EOF
  fi
  chown "$OPENCLAW_USER:$OPENCLAW_USER" /opt/clawbot/config/runtime/llm.yaml
  chmod 640 /opt/clawbot/config/runtime/llm.yaml
fi

if [[ ! -f "$OPENCLAW_LLM_SECRETS_FILE" ]]; then
  cat >"$OPENCLAW_LLM_SECRETS_FILE" <<'EOF'
# Populate API credentials here before running gateway config-sensitive workflows.
# Example:
OPENROUTER_API_KEY=sk-...
# OPENAI_API_KEY=...
EOF
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_LLM_SECRETS_FILE"
  chmod 600 "$OPENCLAW_LLM_SECRETS_FILE"
fi

if [[ ! -f "$OPENCLAW_TELEGRAM_SECRETS_FILE" ]]; then
  cat >"$OPENCLAW_TELEGRAM_SECRETS_FILE" <<'EOF'
TELEGRAM_GROUP_CHAT_ID=-1001234567890
TELEGRAM_BOT_TOKEN_BOB=...
TELEGRAM_BOT_TOKEN_STACKS=...
TELEGRAM_BOT_TOKEN_JENNIFER=...
TELEGRAM_BOT_TOKEN_STEVE=...
TELEGRAM_BOT_TOKEN_NUMBER5=...
EOF
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_TELEGRAM_SECRETS_FILE"
  chmod 600 "$OPENCLAW_TELEGRAM_SECRETS_FILE"
fi

chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR" "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator" "$OPENCLAW_AGENT_CONFIG_DIR/specialists"
chmod 750 "$OPENCLAW_AGENT_CONFIG_DIR" "$OPENCLAW_AGENT_CONFIG_DIR/orchestrator" "$OPENCLAW_AGENT_CONFIG_DIR/specialists"

if [[ -f "$BOOTSTRAP_MARKER" ]]; then
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md" 2>/dev/null || true
  chmod 640 "$OPENCLAW_AGENT_CONFIG_DIR/specialists/podcast_media.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/research.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/engineering.md" "$OPENCLAW_AGENT_CONFIG_DIR/specialists/business.md" 2>/dev/null || true
  run_step "Ensure ufw firewall rules" configure_ufw
  write_openclaw_ctl
  run_step "Configure webhook stack" configure_webhook_stack
  log "openclaw node bootstrap already completed."
  if run_as_openclaw_from_tmp systemctl --user is-active --quiet openclaw.service; then
    run_as_openclaw_from_tmp systemctl --user status openclaw.service --no-pager
  else
    log "openclaw service not active; attempting to restart as part of idempotent check."
    restart_openclaw_service
    wait_for_openclaw_service 60
    run_as_openclaw_from_tmp systemctl --user status openclaw.service --no-pager
  fi
  log_pairing_command
  exit 0
fi

log "Applying base service settings"
run_step "Apply sysctl and restart SSH" sysctl --system && systemctl restart ssh
run_step "Wait for SSH listener" wait_for_sshd 30
run_step "Configure ufw and allow SSH" configure_ufw
run_step "Enable auditd" systemctl enable --now auditd
run_step "Enable fail2ban" systemctl enable --now fail2ban

if id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  loginctl enable-linger "$OPENCLAW_USER" || true
  run_step "Start rootless user service" start_openclaw_user_slice
  run_step "Wait for openclaw user bus" wait_for_user_bus
  run_step "Prepare runtime directory" prepare_rootless_runtime_directory
fi

if ! grep -q '^openclaw:100000:65536$' /etc/subuid; then
  run_step "Add subuid mapping" ensure_subid_mapping /etc/subuid openclaw:100000:65536
fi
if ! grep -q '^openclaw:100000:65536$' /etc/subgid; then
  run_step "Add subgid mapping" ensure_subid_mapping /etc/subgid openclaw:100000:65536
fi
if id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  run_as_openclaw podman system migrate
fi

OPENCLAW_WEBHOOK_PUBLIC_BASE_URL="http://127.0.0.1:${OPENCLAW_WEBHOOK_RECEIVER_PORT}"
if [ -n "${OPENCLAW_PUBLIC_HOSTNAME:-}" ]; then
  OPENCLAW_WEBHOOK_PUBLIC_BASE_URL="https://${OPENCLAW_PUBLIC_HOSTNAME}"
fi

cat > /opt/clawbot/config/openclaw.json <<EOF
{
  "gateway": {
    "mode": "local",
    "controlUi": {
      "allowedOrigins": [
        "http://127.0.0.1:18789",
        "http://localhost:18789"
      ]
    }
  },
  "session": {
    "dmScope": "per-account-channel-peer"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/auto"
      }
    },
    "list": [
      {
        "id": "orchestrator",
        "default": true,
        "workspace": "/state/.openclaw/workspace-orchestrator",
        "identity": $(render_openclaw_identity_json "orchestrator" "Bob")
      },
      {
        "id": "podcast_media",
        "workspace": "/state/.openclaw/workspace-podcast_media",
        "identity": $(render_openclaw_identity_json "podcast_media" "Stacks")
      },
      {
        "id": "research",
        "workspace": "/state/.openclaw/workspace-research",
        "identity": $(render_openclaw_identity_json "research" "Jennifer")
      },
      {
        "id": "engineering",
        "workspace": "/state/.openclaw/workspace-engineering",
        "identity": $(render_openclaw_identity_json "engineering" "Steve")
      },
      {
        "id": "business",
        "workspace": "/state/.openclaw/workspace-business",
        "identity": $(render_openclaw_identity_json "business" "Number 5")
      }
    ]
  },
  "secrets": {
    "providers": {
      "agent_orchestrator_root": {
        "source": "exec",
        "command": "/usr/bin/sudo",
        "args": [
          "-n",
          "/usr/local/bin/openclaw-agent-secret-provider",
          "orchestrator"
        ],
        "jsonOnly": true
      },
      "agent_podcast_media_root": {
        "source": "exec",
        "command": "/usr/bin/sudo",
        "args": [
          "-n",
          "/usr/local/bin/openclaw-agent-secret-provider",
          "podcast_media"
        ],
        "jsonOnly": true
      },
      "agent_research_root": {
        "source": "exec",
        "command": "/usr/bin/sudo",
        "args": [
          "-n",
          "/usr/local/bin/openclaw-agent-secret-provider",
          "research"
        ],
        "jsonOnly": true
      },
      "agent_engineering_root": {
        "source": "exec",
        "command": "/usr/bin/sudo",
        "args": [
          "-n",
          "/usr/local/bin/openclaw-agent-secret-provider",
          "engineering"
        ],
        "jsonOnly": true
      },
      "agent_business_root": {
        "source": "exec",
        "command": "/usr/bin/sudo",
        "args": [
          "-n",
          "/usr/local/bin/openclaw-agent-secret-provider",
          "business"
        ],
        "jsonOnly": true
      }
    }
  }
}
EOF
chown "$OPENCLAW_USER:$OPENCLAW_USER" /opt/clawbot/config/openclaw.json
chmod 600 /opt/clawbot/config/openclaw.json

  if [[ -n "$OPENCLAW_REPO_URL" && ! -d "$OPENCLAW_DIR/.git" ]]; then
    run_step "Clone openclaw repository" git -C "$OPENCLAW_PARENT_DIR" clone --depth 1 --branch "$OPENCLAW_BRANCH" "$OPENCLAW_REPO_URL" "$(basename "$OPENCLAW_DIR")"
  fi
  if [[ -d "$OPENCLAW_DIR" ]]; then
    run_step "Prepare repo ownership" chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_DIR"
    if [[ -f "$OPENCLAW_DIR/Dockerfile" ]]; then
      run_step "Build podman image as openclaw" build_openclaw_image_as_openclaw "$OPENCLAW_IMAGE" "$OPENCLAW_DIR"
      run_step "Wait for openclaw image" wait_for_image "$OPENCLAW_IMAGE" 60
    fi
  fi

  openclaw_llm_env_line=""
  if [[ -f "$OPENCLAW_LLM_SECRETS_FILE" ]]; then
    openclaw_llm_env_line="EnvironmentFile=$OPENCLAW_LLM_SECRETS_FILE"
  fi

  cat >"/home/$OPENCLAW_USER/.config/containers/systemd/openclaw.container" <<EOF
[Unit]
Description=OpenClaw gateway (rootless Podman)

[Container]
Image=$OPENCLAW_IMAGE
ContainerName=openclaw
User=$OPENCLAW_UID:$OPENCLAW_UID
UserNS=keep-id
Notify=no

Volume=/opt/clawbot/config/openclaw.json:/config/openclaw.json:ro
Volume=/opt/clawbot/config/runtime:/config/runtime:ro
Volume=/opt/clawbot/config/agent-config:/config/agent-config:ro
Volume=/opt/clawbot/work:/workspace
Volume=/opt/clawbot/state:/state

EnvironmentFile=/opt/clawbot/config/.env
$openclaw_llm_env_line
Environment=OPENCLAW_CONFIG_PATH=/config/openclaw.json
Environment=OPENCLAW_HOME=/state
Environment=OPENCLAW_WORKSPACE_DIR=/workspace
Environment=TERM=xterm-256color
Environment=OPENCLAW_CONFIG_DIR=/config

PublishPort=127.0.0.1:18789:18789

Pull=never
Exec=node dist/index.js gateway --bind lan --port 18789

[Service]
TimeoutStartSec=300
Restart=on-failure

[Install]
WantedBy=default.target
EOF
  chown root:root "/home/$OPENCLAW_USER/.config/containers/systemd/openclaw.container"
  chmod 0644 "/home/$OPENCLAW_USER/.config/containers/systemd/openclaw.container"

  run_step "Reload openclaw user units" run_as_openclaw_from_tmp systemctl --user daemon-reload
  run_step "Enable openclaw service" enable_openclaw_service
  run_step "Restart openclaw service" restart_openclaw_service
  run_step "Wait for openclaw service" wait_for_openclaw_service 60
  run_step "Check openclaw service" run_as_openclaw_from_tmp systemctl --user status openclaw.service --no-pager
  run_step "Install openclaw helper" write_openclaw_ctl
run_step "Configure webhook stack" configure_webhook_stack
log_pairing_command

touch "$BOOTSTRAP_MARKER"
log "openclaw node bootstrap complete."
