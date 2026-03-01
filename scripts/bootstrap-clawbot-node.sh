#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_DIR="${OPENCLAW_DIR:-/srv/openclaw}"
OPENCLAW_BRANCH="${OPENCLAW_BRANCH:-main}"
OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-}"
OPENCLAW_IMAGE="${OPENCLAW_IMAGE:-localhost/openclaw:local}"
ENABLE_ROOT_SSH="${ENABLE_ROOT_SSH:-no}"
ADMIN_USER="${ADMIN_USER:-ubuntu}"
ADMIN_PUBLIC_KEY="${ADMIN_PUBLIC_KEY:-}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this script as root (for example: sudo bash scripts/bootstrap-clawbot-node.sh)" >&2
  exit 1
fi

log() {
  echo "[INFO] $*"
}

run_as_openclaw() {
  local cmd=$1
  sudo -u "${OPENCLAW_USER}" -H env XDG_RUNTIME_DIR="/run/user/${OPENCLAW_UID}" bash -lc "${cmd}"
}

install_system_packages() {
  local packages=(
    podman
    systemd-container
    dbus
    ca-certificates
    curl
    git
    htop
    tmux
    auditd
    fail2ban
    unattended-upgrades
    openssl
  )

  log "Installing system packages"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
}

apply_ssh_and_hardening() {
  log "Writing SSH and host hardening configuration"
  cat >/etc/ssh/sshd_config.d/99-clawbot-hardening.conf <<'EOF'
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
PubkeyAuthentication yes
LoginGraceTime 30
MaxAuthTries 4
MaxSessions 3
IgnoreRhosts yes
HostbasedAuthentication no
PermitUserEnvironment no
UseDNS no
AllowAgentForwarding no
X11Forwarding no
AllowTcpForwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
Compression no
EOF

  if [[ "${ENABLE_ROOT_SSH}" == "yes" ]]; then
    perl -0pi -e 's/^PermitRootLogin no$/PermitRootLogin yes/m' /etc/ssh/sshd_config.d/99-clawbot-hardening.conf
  fi

  cat >/etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled = true
mode = aggressive
port = ssh
logpath = /var/log/auth.log
maxretry = 5
findtime = 10m
bantime = 6h
EOF

  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

  cat >/etc/apt/apt.conf.d/50unattended-upgrades <<'EOF'
Unattended-Upgrade::Origins-Pattern {
  "origin=Ubuntu,archive=stable,label=Ubuntu";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Mail "root";
EOF

  cat >/etc/sysctl.d/99-clawbot-hardening.conf <<'EOF'
kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 1
fs.protected_regular = 1
fs.suid_dumpable = 0
kernel.yama.ptrace_scope = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF

  cat >/etc/audit/rules.d/99-clawbot.rules <<'EOF'
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /var/log/auth.log -p wa -k auth
-w /etc/ssh/sshd_config -p wa -k sshd_config
EOF
}

configure_admin_key() {
  if [[ -z "${ADMIN_PUBLIC_KEY}" ]]; then
    return 0
  fi

  if ! id -u "${ADMIN_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${ADMIN_USER}"
  fi

  mkdir -p "/home/${ADMIN_USER}/.ssh"
  chmod 700 "/home/${ADMIN_USER}/.ssh"
  touch "/home/${ADMIN_USER}/.ssh/authorized_keys"
  chmod 600 "/home/${ADMIN_USER}/.ssh/authorized_keys"
  if ! grep -qxF "${ADMIN_PUBLIC_KEY}" "/home/${ADMIN_USER}/.ssh/authorized_keys"; then
    printf "%s\n" "${ADMIN_PUBLIC_KEY}" >>"/home/${ADMIN_USER}/.ssh/authorized_keys"
  fi
  chown -R "${ADMIN_USER}:${ADMIN_USER}" "/home/${ADMIN_USER}/.ssh"
  usermod -aG sudo "${ADMIN_USER}" || true
}

bootstrap_openclaw() {
  if ! id -u "${OPENCLAW_USER}" >/dev/null 2>&1; then
    useradd --system --create-home --home-dir "/home/${OPENCLAW_USER}" --shell /usr/sbin/nologin "${OPENCLAW_USER}"
  fi

  mkdir -p /srv /opt/clawbot /opt/clawbot/{config,work,logs}
  mkdir -p "/home/${OPENCLAW_USER}/.config/containers/systemd"
  chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "/home/${OPENCLAW_USER}"
  chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "/home/${OPENCLAW_USER}/.config/containers/systemd"
  chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" /opt/clawbot
  chmod 750 /opt/clawbot /opt/clawbot/config /opt/clawbot/work /opt/clawbot/logs

  sysctl --system
  systemctl restart ssh
  systemctl enable --now auditd
  systemctl enable --now fail2ban

  OPENCLAW_UID="$(id -u "${OPENCLAW_USER}")"
  loginctl enable-linger "${OPENCLAW_USER}" || true
  systemctl start "user@${OPENCLAW_UID}.service" || true
  mkdir -p "/run/user/${OPENCLAW_UID}/containers"
  chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" "/run/user/${OPENCLAW_UID}"
  chmod 700 "/run/user/${OPENCLAW_UID}"

  if ! grep -q '^openclaw:100000:65536$' /etc/subuid; then
    echo "openclaw:100000:65536" >> /etc/subuid
  fi
  if ! grep -q '^openclaw:100000:65536$' /etc/subgid; then
    echo "openclaw:100000:65536" >> /etc/subgid
  fi
  run_as_openclaw "podman system migrate"

  cat > /opt/clawbot/config/openclaw.json <<'EOF'
{
  "gateway": {
    "mode": "local"
  }
}
EOF
  chown "${OPENCLAW_USER}:${OPENCLAW_USER}" /opt/clawbot/config/openclaw.json
  chmod 600 /opt/clawbot/config/openclaw.json

  if [[ ! -f /opt/clawbot/config/.env ]]; then
    openssl rand -hex 32 > /tmp/openclaw_token
    printf "OPENCLAW_GATEWAY_TOKEN=%s\n" "$(cat /tmp/openclaw_token)" >/opt/clawbot/config/.env
    rm -f /tmp/openclaw_token
  fi
  chown "${OPENCLAW_USER}:${OPENCLAW_USER}" /opt/clawbot/config/.env
  chmod 600 /opt/clawbot/config/.env

  cat >"/home/${OPENCLAW_USER}/.config/containers/systemd/openclaw.container" <<EOF
[Unit]
Description=OpenClaw gateway (rootless Podman)

[Container]
Image=${OPENCLAW_IMAGE}
ContainerName=openclaw
User=999:999
UserNS=keep-id

Volume=/opt/clawbot/config:/config
Volume=/opt/clawbot/work:/workspace

EnvironmentFile=/opt/clawbot/config/.env
Environment=OPENCLAW_CONFIG_PATH=/config/openclaw.json
Environment=OPENCLAW_WORKSPACE_DIR=/workspace
Environment=TERM=xterm-256color

PublishPort=18789:18789
PublishPort=18790:18790

Pull=never
Exec=node dist/index.js gateway --bind lan --port 18789

[Service]
TimeoutStartSec=300
Restart=on-failure

[Install]
WantedBy=default.target
EOF
  chown root:root "/home/${OPENCLAW_USER}/.config/containers/systemd/openclaw.container"
  chmod 0644 "/home/${OPENCLAW_USER}/.config/containers/systemd/openclaw.container"

  if [[ -n "${OPENCLAW_REPO_URL}" ]]; then
    if [[ ! -d /srv/openclaw/.git ]]; then
      git -C /srv clone --depth 1 --branch "${OPENCLAW_BRANCH}" "${OPENCLAW_REPO_URL}" openclaw
    fi
    if [[ -d /srv/openclaw ]]; then
      chown -R "${OPENCLAW_USER}:${OPENCLAW_USER}" /srv/openclaw
      if [[ -f /srv/openclaw/Dockerfile ]]; then
        run_as_openclaw "podman image inspect ${OPENCLAW_IMAGE} >/dev/null 2>&1 || cd /srv/openclaw && podman build -t ${OPENCLAW_IMAGE} -f Dockerfile ."
      fi
    fi
  fi
}

finalize_services() {
  systemctl --machine openclaw@ --user daemon-reload || true
  systemctl --machine openclaw@ --user restart openclaw.service || true
  systemctl --machine openclaw@ --user status openclaw.service --no-pager || true
}

verify() {
  run_as_openclaw "podman ps -a"
  run_as_openclaw "podman logs --tail 20 openclaw || true"
}

main() {
  install_system_packages
  apply_ssh_and_hardening
  configure_admin_key
  bootstrap_openclaw
  finalize_services
  verify

  cat <<EOF
Bootstrap complete.
 - openclaw uid/gid: ${OPENCLAW_UID}/$(id -g "${OPENCLAW_USER}")
 - config path: /opt/clawbot/config
 - quadlet file: /home/${OPENCLAW_USER}/.config/containers/systemd/openclaw.container
 - token file: /opt/clawbot/config/.env

Useful checks:
sudo systemctl --machine openclaw@ --user daemon-reload
sudo systemctl --machine openclaw@ --user restart openclaw.service
sudo systemctl --machine openclaw@ --user status openclaw.service --no-pager
sudo -u openclaw bash -lc 'podman ps -a'
EOF
}

main
