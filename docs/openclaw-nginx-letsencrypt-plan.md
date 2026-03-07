# OpenClaw Reverse Proxy + TLS Implementation Notes

This document is no longer a staged rollout TODO. The nginx/certbot/Telegram webhook
stack described here has been implemented and is now part of the normal bootstrap flow.

## Current production shape

Production stack:

- `live/prod/fsn1/clawbot`

Bootstrap now provisions:

- OpenClaw gateway on `127.0.0.1:18789`
- local Telegram relay on `127.0.0.1:9000`
- per-bot OpenClaw Telegram webhook listeners on:
  - `127.0.0.1:18890`
  - `127.0.0.1:18891`
  - `127.0.0.1:18892`
  - `127.0.0.1:18893`
  - `127.0.0.1:18894`
- `nginx` on `80/443`
- `certbot` with persisted Let’s Encrypt material under `/opt/clawbot/tls/letsencrypt`

Public ingress contract:

- `https://agents.satoshis-plebs.com/` returns `404`
- only `/telegram/<bot>` is intended for external webhook traffic

Supported Telegram webhook paths:

- `/telegram/bob`
- `/telegram/jennifer`
- `/telegram/steve`
- `/telegram/stacks`
- `/telegram/number5`

## Bootstrap contract

The stack passes these production inputs into bootstrap:

- `openclaw_enable_webhook_proxy = true`
- `openclaw_public_hostname = "agents.satoshis-plebs.com"`
- `openclaw_letsencrypt_email = "mcintosh@satoshis-plebs.com"`
- `openclaw_bootstrap_runner_url = "https://raw.githubusercontent.com/mcintosh1776/hetzner-clawbot/main/modules/clawbot_server/bootstrap-node-runner.sh"`

Bootstrap also renders:

- explicit Telegram account-to-agent bindings
- `session.dmScope = "per-account-channel-peer"`
- Telegram DM allowlist gating for the trusted owner
- `agents.defaults.model.primary = "openrouter/auto"`

## Rebuild workflow

The standard rebuild flow is to replace the server while preserving the `/opt` volume:

```bash
cd live/prod/fsn1/clawbot
terragrunt apply -auto-approve -replace='hcloud_server.clawbot'
```

This replaces:

- `hcloud_server.clawbot`
- `hcloud_volume_attachment.opt[0]`

It does not destroy the `/opt` volume itself.

## Bootstrap completion rule

Do not test a rebuilt node until cloud-init is fully complete.

Check:

```bash
tail -n 40 /var/log/cloud-init-output.log
```

Wait for both:

- `openclaw node bootstrap complete.`
- `Cloud-init ... finished`

## Verification checklist

Run on the node:

```bash
systemctl is-active nginx clawbot-telegram-webhook
sudo -u openclaw bash -lc 'env HOME=/home/openclaw XDG_RUNTIME_DIR=/run/user/999 systemctl --user is-active openclaw.service'
sudo ss -ltn | grep -E '127.0.0.1:(18789|18890|18891|18892|18893|18894|9000)|:80 |:443 '
curl -I https://agents.satoshis-plebs.com/
curl -I https://agents.satoshis-plebs.com/telegram/bob
curl -I https://agents.satoshis-plebs.com/telegram/jennifer
curl -I https://agents.satoshis-plebs.com/telegram/stacks
sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec openclaw node dist/index.js agents list --bindings --json'
sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec openclaw node dist/index.js models status --json'
```

Expected:

- all three services are `active`
- `/` returns `404`
- each `/telegram/<bot>` returns `405`
- `agents list --bindings --json` shows five explicit Telegram account bindings
- `models status --json` shows:
  - `defaultModel: "openrouter/auto"`
  - no `missingProvidersInUse`

## Telegram webhook registration

Webhook registration is still a Bot API step. On the node:

```bash
sudo bash -lc '
set -a
. /opt/clawbot/config/secrets/telegram.env
set +a

curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_BOB}/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/bob" -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"
echo
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_JENNIFER}/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/jennifer" -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"
echo
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_STEVE}/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/steve" -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"
echo
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_STACKS}/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/stacks" -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"
echo
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN_NUMBER5}/setWebhook" -d "url=https://agents.satoshis-plebs.com/telegram/number5" -d "secret_token=${TELEGRAM_WEBHOOK_SECRET}"
echo
'
```

Then inspect:

```bash
sudo bash -lc '
set -a
. /opt/clawbot/config/secrets/telegram.env
set +a
for name in BOB JENNIFER STEVE STACKS NUMBER5; do
  eval token=\${TELEGRAM_BOT_TOKEN_${name}}
  echo "== ${name} =="
  curl -s "https://api.telegram.org/bot${token}/getWebhookInfo"
  echo
done
'
```

Steady state:

- `pending_update_count: 0`
- no fresh `502 Bad Gateway`
- no fresh `Connection refused`

## Durable file contract

Durable rebuild-safe data belongs under `/opt/clawbot`.

Relevant persisted paths:

- `/opt/clawbot/config/openclaw.json`
- `/opt/clawbot/config/runtime/llm.yaml`
- `/opt/clawbot/config/secrets/llm.env`
- `/opt/clawbot/config/secrets/telegram.env`
- `/opt/clawbot/config/telegram-webhook/`
- `/opt/clawbot/tls/letsencrypt/`
- `/opt/clawbot/bootstrap/openclaw-node-bootstrap-runner.sh`
- `/opt/clawbot/state/`
- `/opt/clawbot/work/`

Anything only under `/srv/openclaw` should be treated as rebuild-ephemeral unless bootstrap
recreates it.

## Notes on old assumptions

The following older assumptions are no longer correct:

- the live stack is not `us-east`; it is `fsn1`
- the recommended rebuild flow is not `terragrunt taint`; it is `terragrunt apply -replace=...`
- bootstrap completion should be checked in `/var/log/cloud-init-output.log`
- webhook traffic is not proxied from `/`; root intentionally returns `404`
- Telegram listeners no longer use `18790-18794`
- the deployment no longer relies on Telegram DM pairing for the owner path
