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
- Terraform now also checks that rendered `user_data` is within Hetzner's `user_data` limit (32,768 characters) before API calls.
- If rendering produces malformed YAML, plan/apply fails with:

  - `Rendered cloud-init is not valid YAML. Check modules/clawbot_server/cloud-init.tftpl for formatting issues.`

If the rendered payload becomes too large, the plan fails with:

- `Rendered cloud-init exceeds Hetzner user_data limit (max 32768 chars). Remove optional/custom payload or reduce cloud-init size before applying.`

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
- Approve the latest pairing request from the latest device (also printed during bootstrap):

  ```bash
  sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec -it openclaw node dist/index.js devices approve --latest'
  ```

## Agent configuration layout

OpenClaw has been treated as a generic orchestrator with specialist role files
stored on the persistent `/opt` volume so the setup survives server replacement:

- `/opt/clawbot/config/agent-config/agent-fleet.yaml`
- `/opt/clawbot/config/agent-config/orchestrator/policy.md`
- `/opt/clawbot/config/agent-config/specialists/stacks.md`
- `/opt/clawbot/config/agent-config/specialists/jennifer.md`
- `/opt/clawbot/config/agent-config/specialists/steve.md`
- `/opt/clawbot/config/agent-config/specialists/business.md`
- `/opt/clawbot/config/runtime/llm.yaml`
- `/opt/clawbot/config/secrets/llm.env`
- `/opt/clawbot/config/secrets/telegram.env`
- `/usr/local/bin/openclaw-ctl`

Bootstrap seeds these files from `modules/clawbot_server/templates/agent-config/*`
on first boot and preserves them on subsequent runs.
Use this layout as your source of truth for role behavior and routing policy.

`agent-fleet.yaml` is the top-level manifest and works as a role map:

```yaml
orchestrator:
  role: bucket-of-bits-orchestrator

specialists:
  - name: stacks
    role: show production and media operations (announcements, clips, on-air support)
    token: stacks
  - name: jennifer
    role: research and recommendations
    token: jennifer
  - name: steve
    role: engineering implementation
    token: steve
```

Seeded specialist intent (for quick reference):

- `stacks`
  - podcast production and media operations
  - content planning/scheduling
  - recording + post-production runbook support
  - episode announcement/social media posting
  - short clip selection/pipeline for highlights
  - support on-air participation with co-host prep
- `jennifer`
  - external research and evidence gathering
  - comparison/evaluation and recommendations
  - clear assumptions and confidence framing
- `steve`
  - implementation design/review guidance
  - build/test support and troubleshooting hints
  - automation/tooling suggestions with rollback-friendly scope

You can add/remove specialist files and update `agent-fleet.yaml` at any time.
The bootstrap copies defaults only if files are missing, so your edits persist
across rebuilds on the same `/opt` volume.

Useful check commands:

- `openclaw-ctl agents`  
  list all seeded files in `/opt/clawbot/config/agent-config`
- `openclaw-ctl agent-config orchestrator/policy.md`  
  print orchestrator policy
- `openclaw-ctl agent-config specialists/jennifer.md`  
  print research specialist policy
- `openclaw-ctl agent-config specialists/stacks.md`  
  print current podcast/media specialist policy
- `openclaw-ctl agent-config specialists/steve.md`  
  print current coding/capability specialist policy
- `sudo -u openclaw bash -lc 'cat /opt/clawbot/config/agent-config/agent-fleet.yaml'`  
  view role map directly

You can replace these files with your own routing and role definitions at any time.
The files are mounted under `/opt`, so they are preserved by the `/opt` rebalance
workflow (`hcloud_volume.opt` + taint/rebuild on `hcloud_server.clawbot`).

### LLM/runtime config and secrets

- LLM runtime settings are in `/opt/clawbot/config/runtime/llm.yaml`.
- Secret values for LLM providers are intentionally not committed and are stored in
  `/opt/clawbot/config/secrets/llm.env` (mode `600`).
  - `OPENROUTER_API_KEY=sk-...` (example)
  - optional `OPENAI_API_KEY=...`
- Telegram routing tokens are intentionally not committed and are stored separately in
  `/opt/clawbot/config/secrets/telegram.env` (mode `600`):
  - `TELEGRAM_GROUP_CHAT_ID=...`
  - `TELEGRAM_BOT_TOKEN_BOB=...`
  - `TELEGRAM_BOT_TOKEN_STACKS=...`
  - `TELEGRAM_BOT_TOKEN_JENNIFER=...`
  - `TELEGRAM_BOT_TOKEN_STEVE=...`
  - `TELEGRAM_BOT_TOKEN_NUMBER5=...`

`agent-fleet.yaml` remains the durable role map for orchestrator and specialists.
Telegram bot credentials stay in `/opt/clawbot/config/secrets/telegram.env`, and
bootstrap renders the bot-to-agent account bindings into `/opt/clawbot/config/openclaw.json`
so API tokens are not stored in the fleet manifest.

## Useful paths on the node

- Repo: `/srv/openclaw`
- Config: `/opt/clawbot/config/openclaw.json`
- Env/token: `/opt/clawbot/config/.env`
- Service: `/home/openclaw/.config/containers/systemd/openclaw.container`
- User service: `openclaw@` under user `openclaw` (uid 999 by default in the current layout)
- Cached bootstrap runner (for rebuild recovery): `/opt/clawbot/bootstrap/openclaw-node-bootstrap-runner.sh`

## Telegram webhook automation (Nginx + certbot + relay)

`live/prod/fsn1/clawbot/terragrunt.hcl` now enables webhook automation for production with:

- `openclaw_enable_webhook_proxy = true`
- `openclaw_public_hostname = "agents.satoshis-plebs.com"`
- `openclaw_letsencrypt_email = "mcintosh@satoshis-plebs.com"`

When enabled, bootstrap performs these actions on the node:

1. Installs `nginx`, `certbot`, `python3-venv`, `fastapi` dependencies.
2. Renders a local webhook relay at `/opt/clawbot/config/telegram-webhook/app.py`.
3. Creates/updates `/etc/systemd/system/clawbot-telegram-webhook.service` and starts it.
4. Writes `/etc/nginx/sites-available/openclaw-webhook.conf` and enables it.
5. Attempts TLS certificate provisioning with Certbot for `agents.satoshis-plebs.com`.
6. Persists/derives `TELEGRAM_WEBHOOK_SECRET` in `/opt/clawbot/config/secrets/telegram.env`.
7. Renders explicit OpenClaw Telegram account bindings so `bob`, `jennifer`, `steve`,
   `stacks`, and `number5` route to their dedicated agents.
8. Ensures certbot renewal timer is enabled (`certbot.timer` or `snap.certbot.renew.timer`) and logs timer status.

This rollout is fully automated from `openclaw-node-bootstrap-runner`. The remaining manual item is Telegram `setWebhook` registration.

The production Telegram channel config is intended for one trusted operator. Direct
messages are scoped per bot account and gated by an allowlist entry for the owner’s
Telegram user ID, rather than interactive pairing.

To verify after bootstrap:

```bash
curl -I https://agents.satoshis-plebs.com/
curl -I https://agents.satoshis-plebs.com/telegram/bob
systemctl is-active --quiet clawbot-telegram-webhook
sudo -u openclaw bash -lc 'cat /opt/clawbot/config/telegram-webhook/app.py | head'
sudo -u openclaw bash -lc 'grep TELEGRAM_WEBHOOK_SECRET /opt/clawbot/config/secrets/telegram.env'
sudo -u openclaw bash -lc 'tail -n 120 /var/log/openclaw-webhook-certbot.log'
```

To wire bot webhooks, register each bot to its own public path. Example for Bob:

```bash
set -a
. /opt/clawbot/config/secrets/telegram.env
set +a

curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_BOB}/setWebhook" \
  -d "url=https://agents.satoshis-plebs.com/telegram/bob" \
  -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"

curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_BOB}/getWebhookInfo"
```

Register the other bots to their matching paths:

```bash
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_STACKS}/setWebhook" \
  -d "url=https://agents.satoshis-plebs.com/telegram/stacks" \
  -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"
```

Current public webhook paths:

- `bob` -> `/telegram/bob`
- `jennifer` -> `/telegram/jennifer`
- `steve` -> `/telegram/steve`
- `stacks` -> `/telegram/stacks`
- `number5` -> `/telegram/number5`

The relay forwards those public paths to dedicated host-local OpenClaw webhook listeners on
`127.0.0.1:18890-18894`. That port block is reserved to avoid collisions with the main gateway
listener on `18789` and other OpenClaw internal ports.

Quick six-item post-bootstrap check list:
1. `curl -I https://agents.satoshis-plebs.com/` (expect HTTP 404, root intentionally not proxied)
2. `curl -I https://agents.satoshis-plebs.com/telegram/bob`
3. `curl -I https://agents.satoshis-plebs.com/telegram/jennifer`
4. `curl -I https://agents.satoshis-plebs.com/telegram/stacks`
5. `systemctl is-active --quiet nginx`
6. `systemctl is-active --quiet clawbot-telegram-webhook`
7. `sudo systemctl status --no-pager clawbot-telegram-webhook`
8. `sudo systemctl --machine openclaw@ --user status openclaw.service --no-pager`
9. `sudo -u openclaw bash -lc 'grep TELEGRAM_WEBHOOK_SECRET /opt/clawbot/config/secrets/telegram.env'`
10. `sudo ss -ltn | grep -E '127.0.0.1:(18890|18891|18892|18893|18894)'`

Troubleshooting when bots reply with plain echoes:
1. Verify relay logs: `journalctl -u clawbot-telegram-webhook -n 100 --no-pager`
2. Verify OpenClaw receives the forwarded payload by watching gateway logs for Telegram path hits.
3. Confirm the per-bot webhook listeners are bound: `sudo ss -ltn | grep -E '127.0.0.1:(18890|18891|18892|18893|18894)'`.

Persisted artifacts for webhook/ingress are rooted in `/opt/clawbot` when possible:

- `/opt/clawbot/config/telegram-webhook/*`
- `/opt/clawbot/config/secrets/telegram.env`

If you add or modify webhook-specific code/templates, keep durable state files in `/opt/clawbot`
so rebuilds via `taint`/`apply` preserve them.
