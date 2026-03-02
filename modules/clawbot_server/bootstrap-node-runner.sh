#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_BOOTSTRAP_LOG="${OPENCLAW_BOOTSTRAP_LOG:-/var/log/openclaw-node-bootstrap.log}"
if [[ -d /var/log ]]; then
  mkdir -p /var/log
  : > "$OPENCLAW_BOOTSTRAP_LOG"
  exec > >(tee -a "$OPENCLAW_BOOTSTRAP_LOG") 2>&1
fi

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
OPENCLAW_REQUIRE_OPT_VOLUME="${OPENCLAW_REQUIRE_OPT_VOLUME:-false}"

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
  local attempt=1

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
    sleep 2
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

assert_opt_volume_mount() {
  if [[ "$OPENCLAW_REQUIRE_OPT_VOLUME" != "true" ]]; then
    return 0
  fi

  if ! mountpoint -q /opt; then
    log "Persistent /opt volume is required but /opt is not mounted."
    return 1
  fi
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

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" "HOME=/home/$OPENCLAW_USER" bash -lc "cd /tmp && $cmd"
}

write_openclaw_ctl() {
  cat >/usr/local/bin/openclaw-ctl <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
RUNTIME_DIR="/run/user/$OPENCLAW_UID"

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
  help          print this help
USAGE
}

run_as_openclaw() {
  local cmd="$1"
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
run_step "Wait for system boot" wait_for_system_boot 30
if ! id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  run_step "Create openclaw user" useradd --system --create-home --home-dir /home/"$OPENCLAW_USER" --shell /usr/sbin/nologin "$OPENCLAW_USER"
fi
OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
assert_opt_volume_mount
run_step "Prepare bootstrap directories" bash -lc "mkdir -p '$OPENCLAW_PARENT_DIR' /opt/clawbot /opt/clawbot/config /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state '/home/$OPENCLAW_USER/.config/containers/systemd' && chown -R '$OPENCLAW_USER:$OPENCLAW_USER' '/home/$OPENCLAW_USER' '/home/$OPENCLAW_USER/.config/containers/systemd' /opt/clawbot && chmod 750 /opt/clawbot /opt/clawbot/config /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state"
ensure_gateway_token

if [[ -f "$BOOTSTRAP_MARKER" ]]; then
  write_openclaw_ctl
  log "openclaw node bootstrap already completed."
  if run_as_openclaw "systemctl --user is-active --quiet openclaw.service"; then
    run_as_openclaw "systemctl --user status openclaw.service --no-pager"
  else
    log "openclaw service not active; attempting to restart as part of idempotent check."
    restart_openclaw_service
    wait_for_openclaw_service 60
    run_as_openclaw "systemctl --user status openclaw.service --no-pager"
  fi
  exit 0
fi

log "Applying base service settings"
run_step "Apply sysctl and restart SSH" sysctl --system && systemctl restart ssh
run_step "Wait for SSH listener" wait_for_sshd 30
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

cat > /opt/clawbot/config/openclaw.json <<'EOF'
{
  "gateway": {
    "mode": "local",
    "controlUi": {
      "allowedOrigins": [
        "http://127.0.0.1:18789",
        "http://localhost:18789"
      ]
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
Environment=OPENCLAW_CONFIG_PATH=/config/openclaw.json
Environment=OPENCLAW_HOME=/state
Environment=OPENCLAW_WORKSPACE_DIR=/workspace
Environment=TERM=xterm-256color

PublishPort=127.0.0.1:18789:18789
PublishPort=127.0.0.1:18790:18790

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

touch "$BOOTSTRAP_MARKER"
log "openclaw node bootstrap complete."
