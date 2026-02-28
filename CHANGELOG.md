# Changelog

All notable changes to this project are documented here.

## [v0.5] - 2026-02-28

### Added

- Added `CHANGELOG.md` for project release notes.
- Added a root-level changelog entry for the initial server-hardening and deployment setup work.

### Changed

- Updated cloud-init template to enforce production baseline hardening:
  - installed packages: `docker`, `docker-compose`, `tmux`, `unattended-upgrades`, `fail2ban`, `auditd`, and support tools.
  - added SSH hardening via `sshd_config.d`, including key-only auth and hardened defaults.
  - added unattended-upgrade settings for automatic OS patching.
  - added kernel/sysctl hardening settings and audit rules for key security files/logs.
- Added creation and ownership assignment for `/opt/clawbot/{config,work,logs}`.
- Simplified compose availability by provisioning Ubuntu `docker-compose` package directly in user data.
- Removed `ipv6_address` from module outputs.

### Infrastructure

- Applied updated Terraform/Terragrunt stack in `live/prod/fsn1/clawbot` with successful replacement rebuild.
- Completed validation confirming:
  - `docker` and `docker-compose` are present and executable.
  - `tmux` is present.
  - `/opt/clawbot` and subdirectories are present with correct owner.
  - `fail2ban` and `auditd` services are active.
