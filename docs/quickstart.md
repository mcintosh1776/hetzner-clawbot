# Clawbot Quickstart

## Prerequisites

- Install `terragrunt`
- Export your Hetzner token:
  - `export HCLOUD_TOKEN=<token>`

## Production stack

The live stack in this repo is:

- `live/prod/fsn1/clawbot`

It provisions:

- a Hetzner `cpx22` Ubuntu node
- a persistent `/opt` volume
- OpenClaw in rootless Podman
- `nginx` + `certbot` for Telegram webhook ingress
- per-bot Telegram webhook listeners
- OpenRouter-backed default model selection
- on-node gateway token generation/persistence under `/opt/clawbot/config/.env`

## Provision or update production

```bash
cd live/prod/fsn1/clawbot
terragrunt init
terragrunt plan
terragrunt apply
```

## Wait for bootstrap to finish

Do not test the node until cloud-init is fully done.

On the node:

```bash
tail -n 40 /var/log/cloud-init-output.log
```

Wait for both lines:

- `openclaw node bootstrap complete.`
- `Cloud-init ... finished`

In practice, replacement-node bootstrap usually takes about 6-12 minutes.

## Post-bootstrap verification

Run on the node:

```bash
systemctl is-active nginx clawbot-telegram-webhook
sudo -u openclaw bash -lc 'env HOME=/home/openclaw XDG_RUNTIME_DIR=/run/user/999 systemctl --user is-active openclaw.service'
sudo ss -ltn | grep -E '127.0.0.1:(18789|18890|18891|18892|18893|18894|9000)|:80 |:443 '
curl -I https://agents.satoshis-plebs.com/
curl -I https://agents.satoshis-plebs.com/telegram/bob
curl -I https://agents.satoshis-plebs.com/telegram/jennifer
curl -I https://agents.satoshis-plebs.com/telegram/stacks
sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec openclaw node dist/index.js status'
sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec openclaw node dist/index.js agents list --bindings --json'
sudo -u openclaw bash -lc 'cd /home/openclaw && podman exec openclaw node dist/index.js models status --json'
```

Expected:

- `nginx`, `clawbot-telegram-webhook`, and `openclaw.service` are all `active`
- `https://agents.satoshis-plebs.com/` returns `404`
- each `/telegram/<bot>` endpoint returns `405`
- `agents list --bindings --json` shows 5 Telegram-bound agents
- the dashboard shows the public bot names (`Bob`, `Jennifer`, `Steve`, `Stacks`, `Number 5`)
  while internal routing still uses the role-oriented ids (`orchestrator`, `research`, `engineering`,
  `podcast_media`, `business`)
- `models status --json` shows:
  - `defaultModel: "openrouter/auto"`
  - no `missingProvidersInUse`

## Control UI access

Tunnel the local gateway port:

```bash
ssh -N -L 18789:127.0.0.1:18789 mcintosh@<server-ip-or-host-alias>
```

Then open:

- `http://localhost:18789/`

## Telegram webhook registration

Bootstrap configures the relay, nginx, TLS, and per-bot listener ports.
You still need to register Telegram webhooks with Bot API.

On the node:

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

Check status:

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

Expected steady state:

- `pending_update_count: 0`
- no fresh `502 Bad Gateway`
- no fresh `Connection refused`

## Rebuild production safely

The normal rebuild workflow is to replace the main server and keep the `/opt` volume.
That preserves durable config, Telegram secrets, TLS material, and runtime state.

From `live/prod/fsn1/clawbot`:

```bash
terragrunt apply -auto-approve -replace='hcloud_server.clawbot'
```

Notes:

- This replaces `hcloud_server.clawbot`
- It detaches and reattaches the `/opt` volume
- It does not destroy the `/opt` volume itself
- Always wait for bootstrap completion before testing the rebuilt node

## One-off host bootstrap script

There is still a non-Terraform host bootstrap helper:

```bash
sudo bash scripts/bootstrap-clawbot-node.sh
```

That is useful for manual fresh-Ubuntu experiments, but the production workflow in this repo
is the `terragrunt` stack above.

## Repo-wide formatting

```bash
terraform fmt -recursive
```
