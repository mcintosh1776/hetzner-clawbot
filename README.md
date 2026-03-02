# hetzner-clawbot

## Quickstart for this project

- Terraform/terragrunt stack is under `live/<env>/<region>/<service>`.
- Common server bootstrap is in `modules/clawbot_server`.
- Runtime bootstrap helper and helpers on the node are in `scripts/`.

## Rebuild the production stack

From repo root:

```bash
cd live/prod/fsn1/clawbot
export OPENCLAW_GATEWAY_TOKEN="<same-token>"
terragrunt init
terragrunt plan
terragrunt apply
```

Notes:

- `OPENCLAW_GATEWAY_TOKEN` is read by the module and passed into cloud-init.
- The bootstrap flow writes that exact token to `/opt/clawbot/config/.env` on the node as `OPENCLAW_GATEWAY_TOKEN=...` if provided.
  - If `OPENCLAW_GATEWAY_TOKEN` is not provided, bootstrap generates one only when `.env` is missing or token is blank.

## Deployment guardrail

Before any `terragrunt apply`, the stack now performs a cloud-init validation check in Terraform:

- Terraform renders `modules/clawbot_server/cloud-init.tftpl` and validates it with `yamldecode(...)`.
- If rendering produces malformed YAML, plan/apply fails with:

  - `Rendered cloud-init is not valid YAML. Check modules/clawbot_server/cloud-init.tftpl for formatting issues.`

This protects against partial bootstrap where SSH users/keys are not applied due to broken user-data.

## Preserve the existing gateway token on rebuild

To avoid token mismatch after a rebuild:

1. Capture current token from a healthy node:

   ```bash
   ssh mcintosh@clawbot-prod \
     "sudo -u openclaw awk -F= '/^OPENCLAW_GATEWAY_TOKEN=/{print \$2}' /opt/clawbot/config/.env"
   ```

2. Export it before apply:

   ```bash
   export OPENCLAW_GATEWAY_TOKEN="paste-token-here"
   ```

3. Run `terragrunt apply`.

If you accidentally rebuild without passing a token and the existing `/opt/clawbot/config/.env` is missing, bootstrap will generate a new one.

## Rebuild only the server while keeping `/opt` persistent

To recycle just the VM and keep `/opt` data on disk:

```bash
cd live/prod/fsn1/clawbot
terragrunt init
terragrunt taint hcloud_server.clawbot
terragrunt apply
```

Why this works:

- `/opt` is a separate `hcloud_volume` (`hcloud_volume.opt`) and is not replaced when only `hcloud_server.clawbot` is tainted.
- Terraform reattaches that same volume via `hcloud_volume_attachment.opt` after the new server is created.
- Cloud-init mounts the attached volume to `/opt` during boot (`openclaw-mount-opt-volume`), so your prior token/config/logs under `/opt/clawbot` are preserved.

Post-rebuild check:

- `openclaw-ctl status`
- `openclaw-ctl ps`
- `sudo -u openclaw cat /opt/clawbot/config/.env`
- Optionally create and confirm a canary file to verify persistent mount:

  ```bash
  sudo -u openclaw bash -lc 'touch /opt/clawbot/config/test && echo ok >/opt/clawbot/config/test'
  ```

  After a server rebuild (`taint` + `apply`), rerun:
  - `sudo -u openclaw bash -lc 'cat /opt/clawbot/config/test'`

## Node helper

The bootstrap writes `/usr/local/bin/openclaw-ctl` on the node for common checks:

- `openclaw-ctl status` / `openclaw-ctl ps`
- `openclaw-ctl restart`
- `openclaw-ctl token` (prints `/opt/clawbot/config/.env`)
- `openclaw-ctl health` (HTTP check against `127.0.0.1:18789`)
- `openclaw-ctl` is helpful for post-rebuild validation while avoiding manual context setup.
- Approve the latest pairing request from the latest device:

  ```bash
  sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec -it openclaw node dist/index.js devices approve --latest'

## Agent configuration layout

OpenClaw has been treated as a generic orchestrator with specialist role files
stored on the persistent `/opt` volume so the setup survives server replacement:

- `/opt/clawbot/config/agent-config/agent-fleet.yaml`
- `/opt/clawbot/config/agent-config/orchestrator/policy.md`
- `/opt/clawbot/config/agent-config/specialists/podcast_media.md`
- `/opt/clawbot/config/agent-config/specialists/research.md`
- `/opt/clawbot/config/agent-config/specialists/business.md`

Bootstrap seeds these files on first boot and preserves them on subsequent runs.
Use this layout as your source of truth for role behavior and routing policy.

Useful check commands:

- `openclaw-ctl agents`  
  list all seeded files in `/opt/clawbot/config/agent-config`
- `openclaw-ctl agent-config orchestrator/policy.md`  
  print orchestrator policy
- `openclaw-ctl agent-config specialists/research.md`  
  print research specialist policy
- `sudo -u openclaw bash -lc 'cat /opt/clawbot/config/agent-config/agent-fleet.yaml'`  
  view role map directly

You can replace these files with your own routing and role definitions at any time.
The files are mounted under `/opt`, so they are preserved by the `/opt` rebalance
workflow (`hcloud_volume.opt` + taint/rebuild on `hcloud_server.clawbot`).
  ```

## Useful paths on the node

- Repo: `/srv/openclaw`
- Config: `/opt/clawbot/config/openclaw.json`
- Env/token: `/opt/clawbot/config/.env`
- Service: `/home/openclaw/.config/containers/systemd/openclaw.container`
- User service: `openclaw@` under user `openclaw` (uid 999 by default in the current layout)
