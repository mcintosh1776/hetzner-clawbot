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
OPENCLAW_AGENT_CONFIG_DIR="${OPENCLAW_AGENT_CONFIG_DIR:-/opt/clawbot/config/agent-config}"
OPENCLAW_LLM_SECRETS_FILE="/opt/clawbot/config/secrets/llm.env"
OPENCLAW_TELEGRAM_SECRETS_FILE="/opt/clawbot/config/secrets/telegram.env"
OPENCLAW_WEBHOOK_DIR="/opt/clawbot/config/telegram-webhook"
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

BOOTSTRAP_MARKER="${BOOTSTRAP_MARKER:-}"
if [ -z "$BOOTSTRAP_MARKER" ]; then
  BOOTSTRAP_MARKER="/var/lib/clawbot/bootstrap.done"
fi

OPENCLAW_PARENT_DIR="${OPENCLAW_PARENT_DIR:-}"
if [ -z "$OPENCLAW_PARENT_DIR" ]; then
  OPENCLAW_PARENT_DIR="$(dirname "$OPENCLAW_DIR")"
fi

log() {
  printf '[%s] [openclaw-bootstrap] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
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
    if [ -S "/run/user/$OPENCLAW_UID/bus" ] && run_as_openclaw "systemctl --user is-active --quiet default.target"; then
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

    run_as_openclaw "systemctl --user is-active --quiet default.target" >/dev/null 2>&1 || true
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
    if run_as_openclaw "systemctl --user restart openclaw.service"; then
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
      awk -F= '!/^OPENCLAW_GATEWAY_TOKEN=/' "$env_file" > /tmp/openclaw_env.new
      printf "OPENCLAW_GATEWAY_TOKEN=%s\n" "$desired_token" >> /tmp/openclaw_env.new
      mv /tmp/openclaw_env.new "$env_file"
    else
      printf "OPENCLAW_GATEWAY_TOKEN=%s\n" "$desired_token" > "$env_file"
    fi
  fi

  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$env_file"
  chmod 600 "$env_file"
  log "Resolved gateway token from ${source}. Existing token present: $( [[ -n "$current_token" ]] && echo yes || echo no )"
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
    if run_as_openclaw "podman image inspect \"$image\" >/dev/null 2>&1"; then
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
    if run_as_openclaw "systemctl --user is-active --quiet openclaw.service"; then
      return 0
    fi

    sleep 2
    ((attempt += 1))
  done

  run_as_openclaw "systemctl --user status openclaw.service --no-pager || true"
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
from fastapi import FastAPI, Header, HTTPException, Request
import httpx

app = FastAPI()

ALLOWED_AGENTS = {"bob", "jennifer", "steve", "number5", "stacks"}
TELEGRAM_SECRET = os.getenv("TELEGRAM_WEBHOOK_SECRET", "")
OPENCLAW_WEBHOOK_TARGETS = {
  "bob": os.getenv("OPENCLAW_TELEGRAM_WEBHOOK_URL_BOB", "http://127.0.0.1:18890/telegram/bob"),
  "stacks": os.getenv("OPENCLAW_TELEGRAM_WEBHOOK_URL_STACKS", "http://127.0.0.1:18891/telegram/stacks"),
  "jennifer": os.getenv("OPENCLAW_TELEGRAM_WEBHOOK_URL_JENNIFER", "http://127.0.0.1:18892/telegram/jennifer"),
  "steve": os.getenv("OPENCLAW_TELEGRAM_WEBHOOK_URL_STEVE", "http://127.0.0.1:18893/telegram/steve"),
  "number5": os.getenv("OPENCLAW_TELEGRAM_WEBHOOK_URL_NUMBER5", "http://127.0.0.1:18894/telegram/number5"),
}

async def forward_to_openclaw(update: dict, agent: str | None = None):
  if not agent:
    raise HTTPException(status_code=404, detail="agent-specific webhook path required")

  target_url = OPENCLAW_WEBHOOK_TARGETS.get(agent)
  if not target_url:
    raise HTTPException(status_code=404, detail="unknown agent")

  async with httpx.AsyncClient(timeout=10) as client:
    try:
      headers = {}
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
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_WEBHOOK_DIR"
  chmod 750 "$OPENCLAW_WEBHOOK_DIR"
  chown "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_WEBHOOK_DIR/.venv" 2>/dev/null || true

  if ! command -v python3 >/dev/null 2>&1; then
    log "Python not available on node; skipping webhook receiver setup."
    return 1
  fi

  if [[ ! -d "$OPENCLAW_WEBHOOK_DIR/.venv" ]]; then
  run_as_openclaw "python3 -m venv '$OPENCLAW_WEBHOOK_DIR/.venv'"
  fi

  if [[ ! -x "$OPENCLAW_WEBHOOK_DIR/.venv/bin/pip" ]]; then
    log "Webhook receiver virtualenv missing pip; reinstalling."
    run_as_openclaw "python3 -m venv '$OPENCLAW_WEBHOOK_DIR/.venv'"
  fi

  run_as_openclaw "$OPENCLAW_WEBHOOK_DIR/.venv/bin/pip install --upgrade pip >/tmp/openclaw-venv-upgrade.log 2>&1 || true"

  if [[ ! -s "$OPENCLAW_WEBHOOK_DIR/.venv/bin/uvicorn" ]] || ! run_as_openclaw "$OPENCLAW_WEBHOOK_DIR/.venv/bin/python -c 'from uvicorn.config import Config; from fastapi import FastAPI; import httpx; print(\"deps-ok\")' >/tmp/openclaw-webhook-import-check.log 2>&1"; then
    run_step "Fix webhook deps" bash -lc "$OPENCLAW_WEBHOOK_DIR/.venv/bin/pip install --upgrade --force-reinstall --no-cache-dir fastapi uvicorn httpx >/tmp/openclaw-webhook-requirements.log 2>&1"
  fi
  render_webhook_app
  write_webhook_systemd_unit
  run_step "Reload systemd for webhook receiver" systemctl daemon-reload
  run_step "Enable webhook receiver service" systemctl enable --now clawbot-telegram-webhook.service
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
  validate_webhook_config
  if [[ "$OPENCLAW_ENABLE_WEBHOOK_PROXY" != "true" ]]; then
    log "OPENCLAW_ENABLE_WEBHOOK_PROXY is not true; skipping webhook proxy setup."
    return 0
  fi

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
  local output
  local rc

  set +e
  output="$(run_as_openclaw "systemctl --user enable openclaw.service 2>&1")"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    return 0
  fi

  if [[ "$output" == *"transient or generated"* ]]; then
    log "openclaw.service is a generated quadlet unit; enable is not required."
    return 0
  fi

  echo "$output"
  return "$rc"
}

run_as_openclaw() {
  local cmd="$1"
  local openclaw_uid
  openclaw_uid="$(id -u "$OPENCLAW_USER")"

  if [[ "$(id -u)" -eq "$openclaw_uid" ]]; then
    XDG_RUNTIME_DIR="/run/user/$openclaw_uid" HOME="/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd"
    return 0
  fi

  if command -v runuser >/dev/null 2>&1; then
    if runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd"; then
      return 0
    fi
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd"
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
  local cmd="$1"
  if [[ "$(id -un)" == "$OPENCLAW_USER" ]]; then
    XDG_RUNTIME_DIR="$RUNTIME_DIR" HOME="/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd"
    return
  fi

  if command -v runuser >/dev/null 2>&1; then
    runuser -u "$OPENCLAW_USER" -- env "XDG_RUNTIME_DIR=$RUNTIME_DIR" "HOME=/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd" && return
  fi

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=$RUNTIME_DIR" "HOME=/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd"
}

case "${1:-status}" in
  status)
    run_as_openclaw "systemctl --user status openclaw.service --no-pager"
    ;;
  ps)
    run_as_openclaw "podman ps -a"
    ;;
  restart)
    run_as_openclaw "systemctl --user restart openclaw.service"
    ;;
  start)
    run_as_openclaw "systemctl --user start openclaw.service"
    ;;
  stop)
    run_as_openclaw "systemctl --user stop openclaw.service"
    ;;
  logs)
    run_as_openclaw "podman logs openclaw"
    ;;
  journal)
    run_as_openclaw "journalctl --user -u openclaw.service --no-pager"
    ;;
  health)
    run_as_openclaw "curl -s -I http://127.0.0.1:18789/ | head"
    ;;
  token)
    run_as_openclaw "cat /opt/clawbot/config/.env"
    ;;
  agents)
    run_as_openclaw "find \"$AGENT_CONFIG_DIR\" -maxdepth 3 -type f | sort"
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
    run_as_openclaw "cat \"$AGENT_CONFIG_DIR/$agent_config_path\""
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
run_step "Prepare bootstrap directories" bash -lc "mkdir -p '$OPENCLAW_PARENT_DIR' /opt/clawbot /opt/clawbot/config /opt/clawbot/config/secrets /opt/clawbot/config/runtime /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state '/home/$OPENCLAW_USER/.config/containers/systemd' && chown -R '$OPENCLAW_USER:$OPENCLAW_USER' '/home/$OPENCLAW_USER' '/home/$OPENCLAW_USER/.config/containers/systemd' /opt/clawbot && chmod 750 /opt/clawbot /opt/clawbot/config /opt/clawbot/config/secrets /opt/clawbot/config/runtime /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state"
run_step "Prepare bootstrap runtime directory" bash -lc "mkdir -p /opt/clawbot/config/runtime && chown -R '$OPENCLAW_USER:$OPENCLAW_USER' /opt/clawbot/config/runtime && chmod 750 /opt/clawbot/config/runtime"
ensure_gateway_token

if [[ ! -d "$OPENCLAW_AGENT_CONFIG_DIR" ]]; then
  run_step "Prepare default agent config templates" bash -lc "mkdir -p '$OPENCLAW_AGENT_CONFIG_DIR/orchestrator' '$OPENCLAW_AGENT_CONFIG_DIR/specialists'"
fi

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
  if run_as_openclaw "systemctl --user is-active --quiet openclaw.service"; then
    run_as_openclaw "systemctl --user status openclaw.service --no-pager"
  else
    log "openclaw service not active; attempting to restart as part of idempotent check."
    restart_openclaw_service
    wait_for_openclaw_service 60
    run_as_openclaw "systemctl --user status openclaw.service --no-pager"
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
  run_step "Prepare runtime directory" bash -lc "mkdir -p '/run/user/$OPENCLAW_UID/containers' && chown -R '$OPENCLAW_USER:$OPENCLAW_USER' '/run/user/$OPENCLAW_UID' && chmod 700 '/run/user/$OPENCLAW_UID'"
fi

if ! grep -q '^openclaw:100000:65536$' /etc/subuid; then
  run_step "Add subuid mapping" bash -lc "echo 'openclaw:100000:65536' >> /etc/subuid"
fi
if ! grep -q '^openclaw:100000:65536$' /etc/subgid; then
  run_step "Add subgid mapping" bash -lc "echo 'openclaw:100000:65536' >> /etc/subgid"
fi
if id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  run_as_openclaw "podman system migrate"
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
    "list": [
      {
        "id": "orchestrator",
        "default": true,
        "workspace": "/state/.openclaw/workspace-orchestrator"
      },
      {
        "id": "podcast_media",
        "workspace": "/state/.openclaw/workspace-podcast_media"
      },
      {
        "id": "research",
        "workspace": "/state/.openclaw/workspace-research"
      },
      {
        "id": "engineering",
        "workspace": "/state/.openclaw/workspace-engineering"
      },
      {
        "id": "business",
        "workspace": "/state/.openclaw/workspace-business"
      }
    ]
  },
  "bindings": [
    {
      "agentId": "orchestrator",
      "match": {
        "channel": "telegram",
        "accountId": "orchestrator"
      }
    },
    {
      "agentId": "podcast_media",
      "match": {
        "channel": "telegram",
        "accountId": "podcast_media"
      }
    },
    {
      "agentId": "research",
      "match": {
        "channel": "telegram",
        "accountId": "research"
      }
    },
    {
      "agentId": "engineering",
      "match": {
        "channel": "telegram",
        "accountId": "engineering"
      }
    },
    {
      "agentId": "business",
      "match": {
        "channel": "telegram",
        "accountId": "business"
      }
    }
  ],
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "allowFrom": [
        "tg:1619231777"
      ],
      "defaultAccount": "orchestrator",
      "accounts": {
        "orchestrator": {
          "botToken": "\${TELEGRAM_BOT_TOKEN_BOB}",
          "webhookUrl": "${OPENCLAW_WEBHOOK_PUBLIC_BASE_URL}/telegram/bob",
          "webhookSecret": "\${TELEGRAM_WEBHOOK_SECRET}",
          "webhookPath": "/telegram/bob",
          "webhookHost": "0.0.0.0",
          "webhookPort": 18890
        },
        "podcast_media": {
          "botToken": "\${TELEGRAM_BOT_TOKEN_STACKS}",
          "webhookUrl": "${OPENCLAW_WEBHOOK_PUBLIC_BASE_URL}/telegram/stacks",
          "webhookSecret": "\${TELEGRAM_WEBHOOK_SECRET}",
          "webhookPath": "/telegram/stacks",
          "webhookHost": "0.0.0.0",
          "webhookPort": 18891
        },
        "research": {
          "botToken": "\${TELEGRAM_BOT_TOKEN_JENNIFER}",
          "webhookUrl": "${OPENCLAW_WEBHOOK_PUBLIC_BASE_URL}/telegram/jennifer",
          "webhookSecret": "\${TELEGRAM_WEBHOOK_SECRET}",
          "webhookPath": "/telegram/jennifer",
          "webhookHost": "0.0.0.0",
          "webhookPort": 18892
        },
        "engineering": {
          "botToken": "\${TELEGRAM_BOT_TOKEN_STEVE}",
          "webhookUrl": "${OPENCLAW_WEBHOOK_PUBLIC_BASE_URL}/telegram/steve",
          "webhookSecret": "\${TELEGRAM_WEBHOOK_SECRET}",
          "webhookPath": "/telegram/steve",
          "webhookHost": "0.0.0.0",
          "webhookPort": 18893
        },
        "business": {
          "botToken": "\${TELEGRAM_BOT_TOKEN_NUMBER5}",
          "webhookUrl": "${OPENCLAW_WEBHOOK_PUBLIC_BASE_URL}/telegram/number5",
          "webhookSecret": "\${TELEGRAM_WEBHOOK_SECRET}",
          "webhookPath": "/telegram/number5",
          "webhookHost": "0.0.0.0",
          "webhookPort": 18894
        }
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
    run_step "Build podman image as openclaw" run_as_openclaw "if podman image inspect \"$OPENCLAW_IMAGE\" >/dev/null 2>&1; then exit 0; fi; cd \"$OPENCLAW_DIR\" && podman build -t \"$OPENCLAW_IMAGE\" -f Dockerfile ."
    run_step "Wait for openclaw image" wait_for_image "$OPENCLAW_IMAGE" 60
  fi
fi

openclaw_llm_env_line=""
if [[ -f "$OPENCLAW_LLM_SECRETS_FILE" ]]; then
  openclaw_llm_env_line="EnvironmentFile=$OPENCLAW_LLM_SECRETS_FILE"
fi

openclaw_telegram_env_line=""
if [[ -f "$OPENCLAW_TELEGRAM_SECRETS_FILE" ]]; then
  openclaw_telegram_env_line="EnvironmentFile=$OPENCLAW_TELEGRAM_SECRETS_FILE"
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

Volume=/opt/clawbot/config:/config
Volume=/opt/clawbot/work:/workspace
Volume=/opt/clawbot/state:/state

EnvironmentFile=/opt/clawbot/config/.env
$openclaw_llm_env_line
$openclaw_telegram_env_line
Environment=OPENCLAW_CONFIG_PATH=/config/openclaw.json
Environment=OPENCLAW_HOME=/state
Environment=OPENCLAW_WORKSPACE_DIR=/workspace
Environment=TERM=xterm-256color
Environment=OPENCLAW_CONFIG_DIR=/config

PublishPort=127.0.0.1:18789:18789
PublishPort=127.0.0.1:18890:18890
PublishPort=127.0.0.1:18891:18891
PublishPort=127.0.0.1:18892:18892
PublishPort=127.0.0.1:18893:18893
PublishPort=127.0.0.1:18894:18894

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

run_step "Reload openclaw user units" run_as_openclaw "systemctl --user daemon-reload"
run_step "Enable openclaw service" enable_openclaw_service
run_step "Restart openclaw service" restart_openclaw_service
run_step "Wait for openclaw service" wait_for_openclaw_service 60
run_step "Check openclaw service" run_as_openclaw "systemctl --user status openclaw.service --no-pager"
run_step "Install openclaw helper" write_openclaw_ctl
run_step "Configure webhook stack" configure_webhook_stack
log_pairing_command

touch "$BOOTSTRAP_MARKER"
log "openclaw node bootstrap complete."
