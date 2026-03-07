# Agent Notes

This repo expects conservative operation around rebuilds and server automation.

- Always ask before running code or commands that change infra, mutate server state, rebuild the node, restart services, or execute test flows.
- After a build or rebuild, do not run tests until bootstrap is complete.
- Bootstrap completion should be confirmed in `/var/log/cloud-init-output.log`.
- The node usually needs about 6 minutes to finish bootstrap.
- Prefer waiting for `openclaw node bootstrap complete.` or the final `Cloud-init ... finished` line before testing nginx, certbot, OpenClaw, or Telegram webhooks.
- Commit changes at reasonable milestones instead of letting local work sit uncommitted for too long.
- Prefer validating a milestone with a build or rebuild before treating it as complete, but only after bootstrap is fully complete.
- When a milestone is ready to ship, update `CHANGELOG.md` with the next version number, commit that change, and create a matching git tag from that version.
