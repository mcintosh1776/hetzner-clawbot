terraform {
  source = "../../../../modules/clawbot_server"
}

locals {
  env_name     = basename(dirname(dirname(get_terragrunt_dir())))
  region_name  = basename(dirname(get_terragrunt_dir()))
  service_name = basename(get_terragrunt_dir())
}

inputs = {
  env      = local.env_name
  name     = "${local.service_name}-${local.env_name}-1"
  location = local.region_name

  server_type = "cpx22"
  ssh_keys   = ["bmurphy@Keiths-MacBook-Air.local"]
  ssh_public_keys = {
    "clawbot-admin-gondor" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgGwNzO+PNhcrPnzEXFBZPLbHY++pfVUfGHnqB2ss8z clawbot-admin@gondor"
    "clawbot-recovery-mcintosh" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFBKNOUcblDEYF2d7DKO63Kwzq5QWIQUCGh5fwcybFAt mcintosh@gondor"
  }
  firewall_ssh_cidrs = ["173.18.93.145/32"]
  bootstrap_users    = ["mcintosh"]
  bootstrap_user_ssh_public_keys = {
    "mcintosh" = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFBKNOUcblDEYF2d7DKO63Kwzq5QWIQUCGh5fwcybFAt mcintosh@gondor"
    ]
  }
  enable_root_ssh    = true

  public_ipv4_enabled = true
  primary_ipv4_enabled = true
  public_ipv6_enabled = false
  opt_volume_size_gb = 10
  opt_volume_fstype = "xfs"

  openclaw_enable_webhook_proxy = true
  openclaw_branch = "v2026.3.11"
  openclaw_agent_pack_repo_url = "git@github.com:mcintosh1776/clawbot-agents.git"
  openclaw_agent_pack_ref = "v0.0.8"
  openclaw_operator_telegram_user_id = "1619231777"
  openclaw_public_hostname = "agents.satoshis-plebs.com"
  openclaw_letsencrypt_email = "mcintosh@satoshis-plebs.com"
  openclaw_private_runtime_public_ids = ["bob", "stacks", "jennifer", "steve", "number5", "qa", "security"]
  openclaw_bootstrap_runner_url = "https://raw.githubusercontent.com/mcintosh1776/hetzner-clawbot/main/modules/clawbot_server/bootstrap-node-runner.sh"
  openclaw_bootstrap_runner_sha256 = "654df715fb390d35d8490dfb8e6fd2eb39061ac1315e614ca1b6f704ba547a78"
}
