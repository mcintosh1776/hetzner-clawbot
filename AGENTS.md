# AGENTS: Working rules for Codex in hetzner-clawbot

## Golden rules
- Do not commit secrets (no API tokens, no private keys).
- Prefer small, reviewable diffs.
- If something is ambiguous, choose the safest default and document a TODO.

## Validate changes
From a stack directory (example: `live/prod/us-east/clawbot`):
- `terragrunt init`
- `terragrunt plan`
- `terragrunt apply` (only when explicitly requested)
- `terragrunt destroy` (only when explicitly requested)

## Formatting
- Terraform: `terraform fmt -recursive`
- Terragrunt: keep HCL tidy; avoid dense one-liners

## Repository conventions
- Terraform modules: `/modules/<name>`
- Terragrunt live stacks: `/live/<env>/<region>/<service>/terragrunt.hcl`
- Modules must not define Terraform backends.
- Terragrunt owns backend/state when configured.

## Provider
- Hetzner Cloud (hcloud)
- Token is passed via `HCLOUD_TOKEN`

## Outputs expected from modules
- server id
- server name
- ipv4 address
- ipv6 address (if available)

## Do NOT do without asking
- Creating or changing remote state backends (S3/Minio/etc.)
- Adding CI (GitHub Actions/GitLab CI)
- Opening SSH to the world (0.0.0.0/0) except for explicit temporary testing with a warning
- Adding unrelated services (databases, monitoring stacks) unless requested
- Running code or commands that change infra, mutate server state, rebuild the node, restart services, or execute test flows

## Safety defaults
- Default server_type is `cpx22` (amd64). Do not assume ARM hosts.
- Prefer least-privilege network access; never broaden firewall rules by default.

## Bootstrap discipline
- Do not run validation, smoke tests, or post-build checks against a rebuilt node until bootstrap is complete.
- Treat bootstrap as complete only after `/var/log/cloud-init-output.log` shows completion. The node usually takes about 6 minutes.
- Prefer waiting for explicit completion markers such as `openclaw node bootstrap complete.` or the final `Cloud-init ... finished` line before testing nginx, certbot, OpenClaw, or Telegram webhook behavior.

## Milestones and releases
- Commit changes at reasonable milestones instead of letting local work accumulate too long.
- Prefer validating a milestone with a build or rebuild before treating it as complete, but only after bootstrap is fully complete.
- When a milestone is ready to ship, update `CHANGELOG.md` with the next version number, commit that change, and create a matching git tag from that version.
