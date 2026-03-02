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

## Node helper

The bootstrap writes `/usr/local/bin/openclaw-ctl` on the node for common checks:

- `openclaw-ctl status` / `openclaw-ctl ps`
- `openclaw-ctl restart`
- `openclaw-ctl token` (prints `/opt/clawbot/config/.env`)
- `openclaw-ctl health` (HTTP check against `127.0.0.1:18789`)
- `openclaw-ctl` is helpful for post-rebuild validation while avoiding manual context setup.

## Useful paths on the node

- Repo: `/srv/openclaw`
- Config: `/opt/clawbot/config/openclaw.json`
- Env/token: `/opt/clawbot/config/.env`
- Service: `/home/openclaw/.config/containers/systemd/openclaw.container`
- User service: `openclaw@` under user `openclaw` (uid 999 by default in the current layout)
