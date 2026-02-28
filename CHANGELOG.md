# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

### Removed
- Removed Docker and docker-compose from cloud-init package set; podman remains the supported container runtime on provisioned nodes.

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
