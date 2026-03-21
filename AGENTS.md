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

## Runtime and queue contract
- See `/docs/bot-runtime-and-queue-contract.md` for the private runtime interface, queue primitives, routing precedence, capability boundaries, and debugging guidance.
- Treat that document as the current platform contract for bot runtime behavior and queue-driven workflows.

## Standing operator authority for readiness testing
- Codex has standing authority to directly run readiness tests for Steve and Sentinel without asking for step-by-step confirmation.
- This includes:
  - inspecting queue state
  - inspecting webhook/runtime/container logs
  - probing private runtimes directly
  - moving readiness tasks through the queue
  - verifying artifacts produced by readiness tasks
- Codex also has standing authority to proceed with Steve/Sentinel platform work needed to make those readiness and coding flows reliable, without re-asking at each intermediate step.
- Use the approved SSH prefix for node inspection and direct readiness testing without conversationally re-asking for permission.
- Approved readiness-testing SSH target for the current node:
  - `ssh -i /home/mcintosh/.ssh/mcintosh-clawbot -o StrictHostKeyChecking=no root@91.107.207.3 ...`
- Do not apply infrastructure changes, rebuild the node, rotate secrets, or make unrelated production changes without explicit operator approval.

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
- If `modules/clawbot_server/bootstrap-node-runner.sh` changes, update both of these in `live/prod/fsn1/clawbot/terragrunt.hcl` before any rebuild or apply:
  - `openclaw_bootstrap_runner_sha256`
  - `openclaw_bootstrap_runner_url`
- The pinned URL must reference the exact commit that contains the bootstrap runner bytes whose SHA is pinned.
- Never rebuild with a bootstrap runner URL/SHA mismatch.

## Milestones and releases
- Commit changes at reasonable milestones instead of letting local work accumulate too long.
- Prefer validating a milestone with a build or rebuild before treating it as complete, but only after bootstrap is fully complete.
- When a milestone is ready to ship, update `CHANGELOG.md` with the next version number, commit that change, and create a matching git tag from that version.
