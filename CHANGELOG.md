# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added rollback-oriented documentation for the webhook rollout and generated-file durability:
  - Added `docs/openclaw-nginx-letsencrypt-plan.md` with staged implementation tasks and validations.
  - Added an explicit "Persisting generated files across rebuilds" section covering which webhook/nginx artifacts must live under `/opt/clawbot` and why.
- Enabled webhook automation defaults in the production Terragrunt stack (`live/prod/fsn1/clawbot/terragrunt.hcl`) for:
  - `openclaw_enable_webhook_proxy = true`
  - `openclaw_public_hostname = "agents.satoshis-plebs.com"`
  - `openclaw_letsencrypt_email = "mcintosh@satoshis-plebs.com"`
- Added bootstrap automation to build the Telegram ingress stack when enabled:
  - installs `nginx` + `certbot`
  - renders and runs a local webhook relay at `/opt/clawbot/config/telegram-webhook/app.py`
  - creates `clawbot-telegram-webhook.service`
  - writes/reloads Nginx proxy config
  - requests Let’s Encrypt cert for the configured hostname
- Added automated bootstrap steps for webhook ingress hardening once enabled:
  - `nginx` is installed and service-enabled/reloaded during bootstrap.
  - Telegram webhook secret is generated once in `/opt/clawbot/config/secrets/telegram.env` when missing.

### Changed
- Updated bootstrap documentation and operational guidance to keep `/opt`-hosted generated artifacts from being silently lost during server rebuilds.
- Opened inbound HTTP/HTTPS at Hetzner firewall level for webhook and TLS flows:
  - `modules/clawbot_server/main.tf` now adds inbound `80/tcp` and `443/tcp` rules.
- Added new module inputs and cloud-init variable plumbing for webhook enablement:
  - `openclaw_public_hostname`
  - `openclaw_letsencrypt_email`
  - `openclaw_enable_webhook_proxy`
  - `openclaw_webhook_receiver_port`

### Fixed
- _None yet._

### Removed
- _None yet._

## [0.7.13] - 2026-03-04

### Added
- Template plumbing for business and runtime LLM configuration in bootstrap delivery:
  - `main.tf` now base64-encodes and passes:
    - `modules/clawbot_server/templates/agent-config/business.md`
    - `modules/clawbot_server/templates/agent-config/llm.yaml`
  - `cloud-init.tftpl` now passes both values to `openclaw-node-bootstrap-runner` via
    `OPENCLAW_BUSINESS_TEMPLATE_B64` and `OPENCLAW_LLM_TEMPLATE_B64`.
  - Quadlet generation now includes `EnvironmentFile=-/config/secrets/llm.env` in
    runner output, ensuring LLM runtime credentials are consistently loaded.
 - UFW bootstrap provisioning now enables HTTP/HTTPS ingress with IPv6 disabled for UFW.

### Fixed
 - Fixed a bootstrap regression where secret env file entries in the generated
  quadlet used a leading-path syntax (`- /config/...`) that produced malformed
  container runtime paths such as `.../.config/containers/systemd/-/config/...`.
  Secrets are now attached as absolute paths only when present.
- Improved bootstrap resilience by explicitly requiring `/opt` volume mounting by default
  (`OPENCLAW_REQUIRE_OPT_VOLUME=true`) and adding extra `/dev/sdb` + `/dev/vdb` candidate
  checks for persistent volume detection.
- Added UFW hardening baseline during bootstrap and moved SSH rule to rate-limited
  `ufw limit 22/tcp` behavior.

### Removed
- _None yet._

## [0.7.8] - 2026-03-03

### Added

- Added explicit OpenClaw agent scaffolding naming and behavior changes:
  - `agent-fleet.yaml` now seeds the orchestrator as `bucket-of-bits-orchestrator`
    with aliases `bob`/`bucket-of-bits`.
  - Specialist defaults are now `stacks`, `jennifer`, and `steve`.
  - Added README documentation for the new specialist scope (including media clips,
    announcements, and on-air participation for Stacks).
- Added `openclaw-ctl` helper subcommands for agent-config inspection:
  - `agents` lists files under `/opt/clawbot/config/agent-config`.
  - `agent-config <relative-path>` prints a selected seed file content.

### Changed

- Moved OpenClaw bootstrap script handling to a fetch-and-fallback model in cloud-init:
  - cloud-init now fetches `/usr/local/bin/openclaw-node-bootstrap-runner` from
    `openclaw_bootstrap_runner_url` when provided.
  - falls back to embedded compressed runner script (`openclaw_bootstrap_runner_script`).
  - reduced early reliance on long inline heredocs in cloud-init.
- Default filesystem for persistent `/opt` volume is now `xfs`.
- Bootstrapping now passes explicit `/opt` volume metadata and mount settings to the runner:
  - `OPENCLAW_OPT_VOLUME_FSTYPE`
  - `OPENCLAW_OPT_VOLUME_ID`
  - `OPENCLAW_OPT_VOLUME_NAME`
  - `OPENCLAW_OPT_VOLUME_WAIT_SECONDS`

### Fixed

- Fixed brittle cloud-init embedding behavior by simplifying bootstrap runner delivery and
  preserving prior behavior when fetch source is unavailable.
- Updated README and seeded policy/docs examples to remove stale specialist names.

### Removed

- Removed previous default specialist naming (`podcast_media`, `research`, `business`)
  from seeded scaffolding and documentation.

## [0.7.6] - 2026-03-02

### Added

- Added optional persistent `/opt` volume support for OpenClaw stacks with dedicated inputs for enablement, size, and filesystem.
- Added a dedicated cloud-init mount script (`openclaw-mount-opt-volume`) to attach and mount the Hetzner volume on `/opt` and persist the mount via `/etc/fstab`.
- Added README guidance for rebuild-only workflows while preserving `/opt`, including boot/service checks and canary file validation.

### Changed

- Wired persistent-volume metadata into bootstrap templating (`id`, `name`, filesystem) so re-attachment survives server taint/rebuild cycles.
- Improved bootstrap sequencing with explicit waits for:
  - system boot settle,
  - SSH listener readiness,
  - rootless user bus availability,
  - image build availability,
  - openclaw service active state.
- Updated openclaw service enable/restart behavior to avoid transient-generator errors from `systemctl --user enable` with quadlet-generated units.
- Made token resolution deterministic during bootstrap:
  - reuse existing `/opt/clawbot/config/.env` token when present,
  - preserve user-supplied `OPENCLAW_GATEWAY_TOKEN` when provided,
  - avoid unnecessary token churn across rebuilds.

### Fixed

- Fixed an intermittent race during first boot where rootless bootstrap proceeded before system/runtime stabilization.
- Fixed gateway token persistence ambiguity by ensuring token source is explicit and `.env` ownership/mode is consistently enforced for `openclaw` user operations.
- Fixed bootstrap runner re-entry behavior to validate and restart `openclaw.service` when marker exists but service is inactive.

### Removed

- Removed the previous implicit assume-mounted `/opt` behavior in favor of explicit persistent-volume detection and mount validation.

## [0.7.5] - 2026-03-02

### Added

- Added a Terraform precondition guard that validates rendered cloud-init YAML at plan/apply time before server replacement.
- SSH hardening now enables TCP forwarding explicitly while keeping forwarding controls explicit (`AllowTcpForwarding yes`, `DisableForwarding no`) in both Terraform cloud-init and the standalone bootstrap script.

### Changed

- OpenClaw quadlet template now defaults to LAN binding for container UI access (`--bind lan`) and writes `allowedOrigins` in `openclaw.json`:
  - `http://127.0.0.1:18789`
  - `http://localhost:18789`
- Cloud-init OpenClaw config now writes valid JSON without escaped quote characters so `openclaw.json` is parseable by the gateway.
- Added explicit runtime ownership/setup checks and stronger guard rails during bootstrap for rootless Podman environments.

### Fixed

- Fixed command-output and context issues in automation that affected diagnostics when checking rootless Podman/user-unit state from remote sessions.
- Fixed bootstrap and hardening path to keep host key/SSH behavior stable across server replacement cycles.

### Removed

- Removed Docker and docker-compose from cloud-init package set; podman remains the supported container runtime on provisioned nodes.


## [0.7.3] - 2026-03-01

### Added

- Added a dedicated `/usr/local/bin/openclaw-ctl` helper for reliable node checks and operational operations (`status`, `ps`, `health`, `token`, etc.).
- Bootstrap runner now writes the helper script on every invocation and after completed runs (including skipped runs when marker exists).

### Changed

- Improved bootstrap runner script generation and templating by moving script emission handling out of inline YAML indentation pitfalls and using explicit line-splitting in cloud-init.
- Updated helper and bootstrap execution flow to run steps through a shared `run_step` helper for clearer logs and easier failure diagnosis.
- Switched quadlet user configuration in bootstrap to use dynamic `openclaw` UID (`User=$OPENCLAW_UID:$OPENCLAW_UID`) instead of hard-coded `999`.

### Fixed

- Fixed malformed helper script execution caused by leading blank/BOM characters in `/usr/local/bin/openclaw-ctl` (now consistently generated as valid Bash).
- Fixed generated cloud-init quoting issues by writing `openclaw-node-bootstrap-runner` content via tokenized line emission.
- Fixed rootless service enable/reload/restart flow by running user-unit operations as the `openclaw` user and explicitly writing back helper installation.

## [0.7.2] - 2026-03-01

### Added

- Added a dedicated bootstrap runner script at `modules/clawbot_server/bootstrap-node-runner.sh`.
- Provisioning now writes `/usr/local/bin/openclaw-node-bootstrap-runner` via cloud-init and executes it from `runcmd`.
- Added `/opt/clawbot/state` as a dedicated OpenClaw state mount and wired `OPENCLAW_HOME=/state` into the quadlet config.

### Changed

- Reworked cloud-init bootstrap flow to delegate non-Terraform and container-runtime setup steps into the runner script for improved determinism and easier iteration.
- Updated cloud-init template escaping by switching to direct runner-script injection from file content instead of embedded command templates.
- Quadlet now uses `Type=simple` and `Notify=no` for compatibility with current service lifecycle behavior.

### Fixed

- Fixed repeated bootstrap failures caused by malformed embedded script interpolation and JSON escaping in user-data rendering.
- Fixed rootless Podman runtime behavior by aligning image ownership/path assumptions (`localhost/openclaw:local`) and openclaw home mounts (`OPENCLAW_CONFIG_PATH`, `OPENCLAW_HOME`, `OPENCLAW_WORKSPACE_DIR`).

## [0.7.1] - 2026-03-01

### Added

- Added explicit OpenClaw quadlet guidance in cloud-init for local rootless execution:
  - `Image=localhost/openclaw:local`
  - `User=999:999`
  - `Environment=OPENCLAW_CONFIG_PATH=/config/openclaw.json`
- Added operational instructions to the setup flow for service lifecycle and openclaw-context Podman checks:
  - `systemctl --machine openclaw@ --user daemon-reload`
  - `systemctl --machine openclaw@ --user restart openclaw.service`
  - `systemctl --machine openclaw@ --user status openclaw.service --no-pager`
  - `sudo -u openclaw bash -lc 'podman ps -a'`
  - `sudo -u openclaw bash -lc 'podman logs openclaw'`

### Changed

- Updated quadlet config env override to pass explicit config file path via `OPENCLAW_CONFIG_PATH`.
- Updated runtime image reference to `localhost/openclaw:local` for rootless Podman image store compatibility.
- Added rootless user runtime setup during cloud-init:
  - ensured `/home/openclaw` ownership is fully assigned to `openclaw`
  - enabled lingering and started `user@<uid>.service`
  - ensured `/run/user/<uid>` runtime directory exists and is writable
  - added subuid/subgid bootstrap entries and ran `podman system migrate`

### Fixed

- Removed rootless image-store mismatch during container startup by building and resolving the image under `openclaw` with tag `localhost/openclaw:local`.
- Fixed missing mount access expectations by aligning podman runtime context via explicit `User=999:999` and keep-id settings with `/opt/clawbot` ownership.

## [0.7.0] - 2026-02-28

### Added

- Added `openclaw.container` quadlet definition at `/home/openclaw/.config/containers/systemd/openclaw.container` via cloud-init with rootless Podman settings, fixed port binds, and environment wiring for OpenClaw.
- Added automatic creation of `/opt/clawbot/config/openclaw.json` with `{ "gateway": { "mode": "local" } }`.
- Added automatic generation of `/opt/clawbot/config/.env` with `OPENCLAW_GATEWAY_TOKEN` when missing.

### Changed

- Hardened cloud-init runtime ownership/permissions for OpenClaw runtime artifacts:
  - `/home/openclaw/.config/containers/systemd`
  - `/opt/clawbot/config/openclaw.json`
  - `/opt/clawbot/config/.env`

### Fixed

- Updated server provisioning so OpenClaw’s quadlet, gateway config, and gateway token are available directly under `/opt/clawbot` after reprovisioning.

## [0.6.5] - 2026-02-28

### Added

- Added enforced `/opt/clawbot` ownership and permission model in cloud-init for container runtime layout:
  - `/opt/clawbot` owner/group `openclaw`
  - `/opt/clawbot/config` owner/group `openclaw`
  - `/opt/clawbot/work` owner/group `openclaw`
  - `/opt/clawbot/logs` owner/group `openclaw`
  - mode `750` for all four directories

### Changed

- Updated cloud-init provisioning flow to create `openclaw` when missing and to set directory ownership to `openclaw` during setup.

### Fixed

- Rebuilt production node (`122385328`) and verified the runtime directories are now correctly provisioned with `openclaw:openclaw` ownership and `drwxr-x---` permissions.

## [0.6.4] - 2026-02-28

### Added

- Added `systemd-container` and `dbus` to required cloud-init bootstrap packages for host-container tooling support.

### Changed

- Updated the base package set so `systemd-container` and `dbus` are guaranteed on every new production node.

### Fixed

- Rebuilt production node (`122384888`) after the package list change and verified:
  - `dbus` installed
  - `systemd-container` installed
  - `/usr/bin/machinectl` present
  - `systemd-machined` enabled
  - `fail2ban` and `auditd` active

## [0.6.3] - 2026-02-28

### Added

- Added rootless systemd Container unit generation to `/usr/local/bin/openclaw-podman-setup` and documented a quadlet-managed startup flow.
- Added host directory preparation for `/opt/clawbot/{config,work,logs}` with restricted permissions for the `openclaw` runtime user.

### Changed

- Updated `openclaw-podman-setup` to write `/home/openclaw/.config/containers/systemd/openclaw.container` pointing to:
  - `Image=openclaw:local`
  - bind mounts from `/opt/clawbot/config` and `/opt/clawbot/work`
  - environment files and vars for `OPENCLAW_CONFIG_DIR` and `OPENCLAW_WORKSPACE_DIR`
- Added `systemd-container` and `dbus` to cloud-init package bootstrap.

### Fixed

- Ensured bootstrap writes and secures `/opt/clawbot/config/openclaw.json` and `/opt/clawbot/config/.env` when running the one-time setup helper.

## [0.6.2] - 2026-02-28

### Added

- Added a host-side one-time Podman bootstrap helper at `/usr/local/bin/openclaw-podman-setup` via `modules/clawbot_server/cloud-init.tftpl`.
- Added OpenClaw bootstrap steps to `docs/quickstart.md` for setup and onboarding flow.

### Changed

- Updated cloud-init bootstrap flow to avoid editing checked-in OpenClaw repository files in place.

## [0.6.1] - 2026-02-28

### Added

- Added configurable bootstrap of the OpenClaw repository into `/srv/openclaw` via cloud-init.

### Changed

- Added `openclaw_repo_url` module input and wired it into cloud-init template rendering.
- Updated default cloud-init bootstrap flow to create `/srv` and clone OpenClaw into `/srv/openclaw`, then set ownership to the bootstrap user.

## [0.5.0] - 2026-02-28

### Added

- Added `CHANGELOG.md`.
- Added root-level changelog entry for server-hardening and deployment bootstrap work.
- Added creation and ownership assignment for `/opt/clawbot/{config,work,logs}` during bootstrapping.

### Changed

- Updated cloud-init to install and configure baseline tools and hardening controls:
  - installed `docker`, `docker-compose`, `tmux`, `unattended-upgrades`, `fail2ban`, and `auditd`.
  - added SSH hardening in `sshd_config.d` with key-only authentication and stricter SSH defaults.
  - added unattended-upgrade policy and package management automation files.
  - added kernel/sysctl hardening settings and audit rules for privileged/auth/security files.
- Updated Terraform module outputs by removing `ipv6_address`.
- Added `enable_root_ssh` toggle behavior for SSH root access policy in cloud-init.

### Fixed

- Rebuilt production server so new bootstrap and hardening settings are applied in place.
- Ensured compose usage is available via `docker-compose` in the provisioning flow.
- Restored successful bootstrap validation for:
  - `docker` + `docker-compose`
  - `tmux`
  - `/opt/clawbot/{config,work,logs}` ownership
  - `fail2ban` and `auditd` services running

### Security

- Hardened SSH and host system posture as part of baseline config:
  - disabled password and challenge-response auth
  - enabled audit logging rules for key auth-sensitive paths
