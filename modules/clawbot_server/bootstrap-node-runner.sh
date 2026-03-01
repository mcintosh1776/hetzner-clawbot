#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER}"
if [ -z "$OPENCLAW_USER" ]; then
  OPENCLAW_USER="openclaw"
fi

OPENCLAW_DIR="${OPENCLAW_DIR}"
if [ -z "$OPENCLAW_DIR" ]; then
  OPENCLAW_DIR="/srv/openclaw"
fi

OPENCLAW_BRANCH="${OPENCLAW_BRANCH}"
if [ -z "$OPENCLAW_BRANCH" ]; then
  OPENCLAW_BRANCH="main"
fi

OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL}"
if [ -z "$OPENCLAW_REPO_URL" ]; then
  OPENCLAW_REPO_URL="https://github.com/openclaw/openclaw.git"
fi

OPENCLAW_IMAGE="${OPENCLAW_IMAGE}"
if [ -z "$OPENCLAW_IMAGE" ]; then
  OPENCLAW_IMAGE="localhost/openclaw:local"
fi

BOOTSTRAP_MARKER="${BOOTSTRAP_MARKER}"
if [ -z "$BOOTSTRAP_MARKER" ]; then
  BOOTSTRAP_MARKER="/var/lib/clawbot/bootstrap.done"
fi

OPENCLAW_PARENT_DIR="${OPENCLAW_PARENT_DIR}"
if [ -z "$OPENCLAW_PARENT_DIR" ]; then
  OPENCLAW_PARENT_DIR="$(dirname "$OPENCLAW_DIR")"
fi

log() {
  echo "[openclaw-bootstrap] $*"
}

run_as_openclaw() {
  local cmd="$1"
  local openclaw_uid
  openclaw_uid="$(id -u "$OPENCLAW_USER")"

  sudo -u "$OPENCLAW_USER" -H env "XDG_RUNTIME_DIR=/run/user/$openclaw_uid" bash -lc "$cmd"
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this as root (for example: sudo bash /usr/local/bin/openclaw-node-bootstrap-runner)" >&2
  exit 1
fi

mkdir -p /var/lib/clawbot
if [[ -f "$BOOTSTRAP_MARKER" ]]; then
  log "openclaw node bootstrap already completed."
  exit 0
fi

log "Applying base service settings"
sysctl --system
systemctl restart ssh
systemctl enable --now auditd
systemctl enable --now fail2ban

if ! id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir /home/"$OPENCLAW_USER" --shell /usr/sbin/nologin "$OPENCLAW_USER"
fi

mkdir -p "$OPENCLAW_PARENT_DIR" /opt/clawbot /opt/clawbot/config /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state
mkdir -p "/home/$OPENCLAW_USER/.config/containers/systemd"
chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER"
chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/home/$OPENCLAW_USER/.config/containers/systemd"
chown -R "$OPENCLAW_USER:$OPENCLAW_USER" /opt/clawbot
chmod 750 /opt/clawbot /opt/clawbot/config /opt/clawbot/work /opt/clawbot/logs /opt/clawbot/state

if id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
  loginctl enable-linger "$OPENCLAW_USER" || true
  systemctl start "user@$OPENCLAW_UID.service" || true
  mkdir -p "/run/user/$OPENCLAW_UID/containers"
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "/run/user/$OPENCLAW_UID"
  chmod 700 "/run/user/$OPENCLAW_UID"
fi

if ! grep -q '^openclaw:100000:65536$' /etc/subuid; then
  echo 'openclaw:100000:65536' >> /etc/subuid
fi
if ! grep -q '^openclaw:100000:65536$' /etc/subgid; then
  echo 'openclaw:100000:65536' >> /etc/subgid
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

if [[ ! -f /opt/clawbot/config/.env ]]; then
  TOKEN="$(openssl rand -hex 32 2>/dev/null || tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)"
  printf "OPENCLAW_GATEWAY_TOKEN=%s\n" "$TOKEN" >/opt/clawbot/config/.env
fi
chown "$OPENCLAW_USER:$OPENCLAW_USER" /opt/clawbot/config/.env
chmod 600 /opt/clawbot/config/.env

if [[ -n "$OPENCLAW_REPO_URL" && ! -d "$OPENCLAW_DIR/.git" ]]; then
  git -C "$OPENCLAW_PARENT_DIR" clone --depth 1 --branch "$OPENCLAW_BRANCH" "$OPENCLAW_REPO_URL" "$(basename "$OPENCLAW_DIR")"
fi
if [[ -d "$OPENCLAW_DIR" ]]; then
  chown -R "$OPENCLAW_USER:$OPENCLAW_USER" "$OPENCLAW_DIR"
  if [[ -f "$OPENCLAW_DIR/Dockerfile" ]]; then
    run_as_openclaw "podman image inspect \"$OPENCLAW_IMAGE\" >/dev/null 2>&1 || cd \"$OPENCLAW_DIR\" && podman build -t \"$OPENCLAW_IMAGE\" -f Dockerfile ."
  fi
fi

cat >"/home/$OPENCLAW_USER/.config/containers/systemd/openclaw.container" <<EOF
[Unit]
Description=OpenClaw gateway (rootless Podman)

[Container]
Image=$OPENCLAW_IMAGE
ContainerName=openclaw
User=999:999
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
Type=simple

[Install]
WantedBy=default.target
EOF
chown root:root "/home/$OPENCLAW_USER/.config/containers/systemd/openclaw.container"
chmod 0644 "/home/$OPENCLAW_USER/.config/containers/systemd/openclaw.container"

systemctl --machine openclaw@ --user daemon-reload || true
systemctl --machine openclaw@ --user restart openclaw.service || true
systemctl --machine openclaw@ --user status openclaw.service --no-pager || true

touch "$BOOTSTRAP_MARKER"
log "openclaw node bootstrap complete."
