# OpenClaw Reverse Proxy + TLS Rollout TODO

## Scope
- Use webhooks path through Nginx + HTTPS at:
- `https://agents.satoshis-plebs.com`
- Keep `/opt` persistence and bootstrap idempotency intact.
- Do each stage in a separate commit/tag/rebuild until it passes.
- TLS issuance is best-effort: webhook bootstrap continues on certbot failure and logs explicit warnings.

## Concrete rollout sequence (for rebuild-driven execution)

Use this exact sequence for the next clean rebuild:

1. Confirm required inputs and current state
   - DNS points `agents.satoshis-plebs.com` to the target server IP.
   - `/opt` is enabled and has persisted data:
     - `/opt/clawbot/config/secrets/telegram.env` exists.
     - `/opt/clawbot/config/openclaw.json` exists.
     - `/opt/clawbot/config/agent-config/` files exist.
   - Cloud-init contract values are set in stack:
     - `openclaw_enable_webhook_proxy = true`
     - `openclaw_public_hostname = "agents.satoshis-plebs.com"`
     - `openclaw_letsencrypt_email = "mcintosh@satoshis-plebs.com"`

2. Capture token (optional, for continuity)
   - `OPENCLAW_GATEWAY_TOKEN="$(sudo -u openclaw awk -F= '/^OPENCLAW_GATEWAY_TOKEN=/{print $2}' /opt/clawbot/config/.env)"`
   - Export it for apply if you want deterministic continuity.

3. Rebuild server only (preserve volume):
   - `terragrunt taint hcloud_server.clawbot`
   - `terragrunt apply`

4. Wait for bootstrap completion and avoid early checks:
   - SSH in only after `/var/log/openclaw-node-bootstrap.log` ends with:
     - `openclaw node bootstrap complete.`

5. Run automated post-bootstrap checks in order:
   - `curl -I http://agents.satoshis-plebs.com/`
   - `curl -I https://agents.satoshis-plebs.com/telegram/bob`
   - `systemctl is-active --quiet nginx`
   - `systemctl is-active --quiet clawbot-telegram-webhook`
   - `sudo -u openclaw bash -lc 'grep TELEGRAM_WEBHOOK_SECRET /opt/clawbot/config/secrets/telegram.env'`
   - `curl -I http://127.0.0.1:18789/`

6. Register Telegram webhooks (manual, one-time per token):
   - `set -a; . /opt/clawbot/config/secrets/telegram.env; set +a`
   - `curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_BOB}/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/bob" -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"`
   - Repeat for `jennifer`, `steve`, `number5`, `stacks`.
   - Validate each via `getWebhookInfo`.

## 0) Pre-flight check (do this now)
1. Confirm cloud-init + Terragrunt stack still apply cleanly.
   - Verify `hcl` still renders within Hetzner's `user_data` cap (32,768 chars) before rebuild so oversized payloads fail in plan instead of API apply.
2. Confirm SSH and bootstrap completion checks are available:
   - `openclaw-ctl status`
   - `openclaw-ctl health`
3. Confirm `/opt/clawbot/config` contains:
   - `agent-config` files
   - `runtime/llm.yaml`
   - `secrets/llm.env`
   - `secrets/telegram.env`
4. Confirm DNS A record:
   - `agents.satoshis-plebs.com -> <public_ipv4>`

## 1) Add bootstrap contract (code-only, no runtime side effects)
Update bootstrap inputs and defaults so proxy config is explicit:

- Add env vars in `modules/clawbot_server/bootstrap-node-runner.sh`:
  - `OPENCLAW_PUBLIC_HOSTNAME`
  - `OPENCLAW_LETSENCRYPT_EMAIL`
  - `OPENCLAW_ENABLE_WEBHOOK_PROXY` (default `false`)
- Add cloud-init pass-through in `modules/clawbot_server/main.tf` / `cloud-init.tftpl`
  so the runner sees those values.
- Add a strict pre-check function:
  - If `OPENCLAW_ENABLE_WEBHOOK_PROXY=true` and hostname/email missing: fail fast with a clear message.
  - If hostname format invalid: fail fast.

### Validation after Stage 1
- Rebuild + wait for bootstrap finish.
- Confirm log contains:
  - `Resolved OPENCLAW_PUBLIC_HOSTNAME=agents.satoshis-plebs.com` (or selected value)
  - no early contract failures.

### Rollback
- Set `OPENCLAW_ENABLE_WEBHOOK_PROXY=false` for next run.

## 2) Install packages
Implement an idempotent install step:
- `apt-get update`
- `apt-get install -y nginx certbot python3-certbot-nginx`

### Validation after Stage 2
- `command -v nginx`
- `command -v certbot`
- `nginx -t` returns 0.

### Rollback
- Keep package install function gated by flag, so proxy can be disabled.

## 3) Write nginx site config
Create/regen `/etc/nginx/sites-available/openclaw.conf` and enable it:

- Proxy to local OpenClaw on `127.0.0.1:18789`
- Keep only required paths:
  - `/.well-known/acme-challenge/` direct passthrough
  - `/` and `/telegram/` proxy to OpenClaw
- Add short timeout and conservative headers.
- Ensure symlink: `/etc/nginx/sites-enabled/openclaw.conf`
- Remove default vhost if it conflicts.

### Validation after Stage 3
- `nginx -t`
- `systemctl reload nginx`
- `curl -sSf http://agents.satoshis-plebs.com/` returns HTTP (200/301) once DNS resolves.

### Rollback
- Remove symlink and disable site, then reload nginx.

## 4) Provision Let’s Encrypt certificate
Run cert issuance in bootstrap after nginx config is active:
- `certbot --nginx -d agents.satoshis-plebs.com --non-interactive --agree-tos -m <email> --redirect`
- Bootstrap writes certificate command output to `/var/log/openclaw-webhook-certbot.log`.
- If certbot fails, bootstrap logs a warning and continues with HTTP.

### Validation after Stage 4
- `/etc/letsencrypt/live/agents.satoshis-plebs.com/` exists only if cert issuance succeeds.
- `curl -I https://agents.satoshis-plebs.com/` returns `HTTP/2 200` or `HTTP/1.1 200` only when HTTPS is active.
- `nginx -T` contains SSL block for `agents.satoshis-plebs.com` when cert issuance succeeded.
- If TLS was not issued, confirm warning in `/var/log/openclaw-node-bootstrap.log` and validate HTTP path instead:
  - `grep -i \"WARN\" /var/log/openclaw-node-bootstrap.log | grep -i \"certbot\"`

### Rollback
- Leave HTTP backend enabled and keep HTTPS disabled if certbot fails.

## 5) Renewal hygiene
Enable renewals:
- verify `systemctl list-timers --all | grep -E 'certbot.timer|snap.certbot.renew.timer'` includes timer state
- if timer is present but not enabled, enable it during bootstrap and in follow-up checks

### Validation after Stage 5
- Next dry-run:
  - `certbot renew --dry-run`
- confirm `systemctl list-timers --all | grep -E 'certbot.timer|snap.certbot.renew.timer'` shows a scheduled run.

### Rollback
- No destructive rollback needed; renewal is additive.

## 6) Telegram webhook configuration (post-bootstrap)
Register bot webhooks after service is healthy:
- For each bot token (`BOB/Stacks/Jennifer/Steve/Number5`) run:
  - `curl -s "https://api.telegram.org/bot<TOKEN>/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/<agent_slug>"`
- Confirm each:
  - `curl -s "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"`

### Validation after Stage 6
- Telegram update can arrive to local endpoint through HTTPS proxy.
- Outbound responses return successful `sendMessage` behavior.

### Rollback
- `setWebhook` to empty string for each token to disable:
  - `curl -s "https://api.telegram.org/bot<TOKEN>/setWebhook" -d "url="`

## 7) Final verification checklist (do this before marking done)
1. Wait for bootstrap completion:
   - `openclaw node bootstrap complete.` in `/var/log/openclaw-node-bootstrap.log`
2. Service health:
   - `openclaw-ctl status`
   - `openclaw-ctl health`
3. Local gateway:
   - `curl -s -I http://127.0.0.1:18789/ | head`
4. Public HTTPS:
   - `curl -s -I https://agents.satoshis-plebs.com/telegram/` should not show connection reset.
5. Firewall posture:
   - `ufw status verbose` includes `22/tcp`, `80/tcp`, `443/tcp`.

## Persisting generated files across rebuilds (required contract)

Before adding any new generated artifact (Nginx snippets, webhook receiver files, scripts, cert helper files), confirm it is rooted under `/opt/clawbot` or another explicitly preserved mount.

Current contract for this project:
- `/opt/clawbot` and `/var/lib/clawbot` are the only host-side durable locations for rebuild-safe data.
- Anything under `/srv/openclaw` is ephemeral unless explicitly copied back into `/opt/clawbot`.
- `/opt/clawbot/config/secrets/{llm.env,telegram.env}` is durable but intentionally human-managed; bootstrap never rotates these files.
- `openclaw-ctl` only reads generated/service artifacts from `/opt/clawbot/...` paths.

For this rollout, place durable webhook/nginx runtime files as:
- `/opt/clawbot/config/telegram-webhook/` for local app code/config if you add a local relay
- `/opt/clawbot/config/secrets/` for new webhook secrets
- `/opt/clawbot/config/runtime/` for routing/env metadata variants
- `/opt/clawbot/config/webhook/` for helper manifests (if added)

If a required file lands outside `/opt` and is not in `/etc` by design, it should be expected to be ephemeral and must be re-created on each rebuild.

## One change per stage rule
- Do not merge or commit multiple stages together.
- For each stage:
  - edit one stage,
  - commit/tag,
  - taint+apply server,
  - wait for bootstrap completion,
  - run the stage validation,
  - move on only if green.
