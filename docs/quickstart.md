# Clawbot Quickstart

## Prerequisites

- Install `terragrunt`
- Export Hetzner token in your shell:
  - `export HCLOUD_TOKEN=<token>`

## One-time bootstrap script (non-Terraform, fresh Ubuntu 24.04 node)

```bash
export OPENCLAW_REPO_URL=https://github.com/<your-openclaw-fork-or-upstream>.git
export ADMIN_PUBLIC_KEY='ssh-ed25519 ...'
sudo bash scripts/bootstrap-clawbot-node.sh
```

Optional overrides:

- `OPENCLAW_USER` (default `openclaw`)
- `OPENCLAW_DIR` (default `/srv/openclaw`)
- `OPENCLAW_BRANCH` (default `main`)
- `OPENCLAW_IMAGE` (default `localhost/openclaw:local`)
- `ENABLE_ROOT_SSH=yes` (default `no`)

The script applies hardening, creates `/opt/clawbot/{config,work,logs}`, writes
`/home/openclaw/.config/containers/systemd/openclaw.container`, and starts the service.

## Provision (prod)

```bash
cd live/prod/us-east/clawbot
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output
terragrunt destroy
```

## One-time OpenClaw Podman setup on the host

After first provision (or any reprovision), run:

```bash
sudo openclaw-podman-setup
```

This creates `/opt/clawbot/config/openclaw.json`, `/opt/clawbot/config/.env` and writes
`/home/openclaw/.config/containers/systemd/openclaw.container` for rootless Podman.

Enable the user service:

```bash
sudo systemctl --machine openclaw@ --user daemon-reload
sudo systemctl --machine openclaw@ --user restart openclaw.service
sudo systemctl --machine openclaw@ --user status openclaw.service
```

Then onboard once:

```bash
sudo -u openclaw /home/openclaw/run-openclaw-podman.sh launch setup
```

Start the gateway afterward (if not using the quadlet service):

```bash
sudo -u openclaw /home/openclaw/run-openclaw-podman.sh launch
```

Optional debug (no auto cleanup):

```bash
sudo -u openclaw podman run --name=openclaw-debug --replace --userns keep-id \
  -v /opt/clawbot/config:/config -v /opt/clawbot/work:/workspace \
  --env OPENCLAW_CONFIG_DIR=/config --env OPENCLAW_WORKSPACE_DIR=/workspace \
  --env-file /opt/clawbot/config/.env --publish 18789:18789 --publish 18790:18790 \
  openclaw:local node dist/index.js gateway --bind lan --port 18789
```

Optional local-only bind for hardened access:

```bash
sudo -u openclaw podman run --replace --userns keep-id \
  -v /opt/clawbot/config:/config -v /opt/clawbot/work:/workspace \
  --env OPENCLAW_CONFIG_DIR=/config --env OPENCLAW_WORKSPACE_DIR=/workspace \
  --env-file /opt/clawbot/config/.env --publish 127.0.0.1:18789:18789 \
  --publish 127.0.0.1:18790:18790 openclaw:local node dist/index.js gateway --bind loopback --port 18789
```

## Provision (stage)

```bash
cd live/stage/us-east/clawbot
terragrunt init
terragrunt plan
terragrunt apply
terragrunt destroy
```

## Validation/formatting commands (repo-wide)

```bash
terraform fmt -recursive
```

## Notes

- Remote backend is not configured by default; state is local unless configured in Terragrunt.
- Firewall policy is least-privilege by default (`firewall_ssh_cidrs = []` means SSH is not publicly reachable until allowlist is set).
