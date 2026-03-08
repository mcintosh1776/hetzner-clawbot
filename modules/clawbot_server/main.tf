terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

locals {
  agent_fleet_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/agent-fleet.yaml")
  )
  agent_orchestrator_policy_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/orchestrator-policy.md")
  )
  agent_stacks_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/specialists/stacks.md")
  )
  agent_jennifer_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/specialists/jennifer.md")
  )
  agent_steve_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/specialists/steve.md")
  )
  agent_business_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/specialists/business.md")
  )
  llm_template_b64 = base64gzip(
    file("${path.module}/templates/agent-config/llm.yaml")
  )
  bootstrap_runner_script = trimspace(var.openclaw_bootstrap_runner_url) != "" ? "" : base64gzip(file("${path.module}/bootstrap-node-runner.sh"))
  rendered_cloud_init = trimspace(var.cloud_init) != "" ? var.cloud_init : templatefile(
    "${path.module}/cloud-init.tftpl",
    {
      users                                 = var.bootstrap_users
      user_ssh_authorized_keys              = var.bootstrap_user_ssh_public_keys
      enable_root_ssh                       = var.enable_root_ssh
      openclaw_repo_url                     = var.openclaw_repo_url
      openclaw_branch                       = var.openclaw_branch
      openclaw_agent_pack_repo_url          = var.openclaw_agent_pack_repo_url
      openclaw_agent_pack_ref               = var.openclaw_agent_pack_ref
      openclaw_gateway_token                = var.openclaw_gateway_token
      openclaw_opt_volume_enabled           = var.opt_volume_enabled
      openclaw_opt_volume_fstype            = var.opt_volume_fstype
      openclaw_opt_volume_id                = var.opt_volume_enabled ? hcloud_volume.opt[0].id : ""
      openclaw_opt_volume_name              = var.opt_volume_enabled ? hcloud_volume.opt[0].name : ""
      openclaw_bootstrap_runner_url         = var.openclaw_bootstrap_runner_url
      openclaw_bootstrap_runner_sha256      = var.openclaw_bootstrap_runner_sha256
      openclaw_bootstrap_runner_script      = local.bootstrap_runner_script
      openclaw_agent_fleet_template         = local.agent_fleet_template_b64
      openclaw_orchestrator_policy_template = local.agent_orchestrator_policy_template_b64
      openclaw_stacks_template              = local.agent_stacks_template_b64
      openclaw_jennifer_template            = local.agent_jennifer_template_b64
      openclaw_steve_template               = local.agent_steve_template_b64
      openclaw_business_template            = local.agent_business_template_b64
      openclaw_llm_template                 = local.llm_template_b64
      openclaw_public_hostname              = var.openclaw_public_hostname
      openclaw_letsencrypt_email            = var.openclaw_letsencrypt_email
      openclaw_enable_webhook_proxy         = var.openclaw_enable_webhook_proxy
      openclaw_webhook_receiver_port        = var.openclaw_webhook_receiver_port
      openclaw_private_runtime_public_ids_csv = join(",", var.openclaw_private_runtime_public_ids)
    }
  )
  cloud_init_is_valid_yaml = can(yamldecode(local.rendered_cloud_init))
  ssh_key_names = distinct(concat(
    var.ssh_keys,
    [for key in hcloud_ssh_key.managed : key.name]
  ))
}

resource "hcloud_ssh_key" "managed" {
  for_each = var.ssh_public_keys

  name       = each.key
  public_key = each.value
}

resource "hcloud_firewall" "clawbot" {
  name = "${var.name}-firewall"

  dynamic "rule" {
    for_each = var.firewall_ssh_cidrs
    iterator = cidr

    content {
      direction   = "in"
      protocol    = "tcp"
      port        = "22"
      source_ips  = [cidr.value]
      description = "Allow SSH for ${var.name}"
    }
  }

  rule {
    direction       = "out"
    protocol        = "tcp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow outbound TCP for ${var.name}"
  }

  dynamic "rule" {
    for_each = var.openclaw_enable_webhook_proxy ? toset(["80", "443"]) : toset([])
    iterator = ingress_port

    content {
      direction   = "in"
      protocol    = "tcp"
      port        = ingress_port.value
      source_ips  = ["0.0.0.0/0", "::/0"]
      description = "Allow ingress port ${ingress_port.value} for ${var.name}"
    }
  }

  rule {
    direction       = "out"
    protocol        = "udp"
    port            = "1-65535"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow outbound UDP for ${var.name}"
  }

  rule {
    direction       = "out"
    protocol        = "icmp"
    destination_ips = ["0.0.0.0/0", "::/0"]
    description     = "Allow outbound ICMP for ${var.name}"
  }
}

resource "hcloud_volume" "opt" {
  count    = var.opt_volume_enabled ? 1 : 0
  name     = "${var.name}-opt"
  size     = var.opt_volume_size_gb
  location = var.location
  format   = var.opt_volume_fstype
}

resource "hcloud_volume_attachment" "opt" {
  count = var.opt_volume_enabled ? 1 : 0

  volume_id = hcloud_volume.opt[count.index].id
  server_id = hcloud_server.clawbot.id
}

resource "hcloud_primary_ip" "ipv4" {
  count = var.primary_ipv4_enabled ? 1 : 0

  name          = "${var.name}-ipv4"
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
  location      = var.location

  labels = {
    env  = var.env
    role = var.role
  }
}

resource "hcloud_server" "clawbot" {
  name        = var.name
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location

  public_net {
    ipv4_enabled = var.public_ipv4_enabled
    ipv4         = var.primary_ipv4_enabled ? hcloud_primary_ip.ipv4[0].id : null
    ipv6_enabled = var.public_ipv6_enabled
  }

  ssh_keys = local.ssh_key_names

  labels = {
    env  = var.env
    role = var.role
  }

  firewall_ids = [hcloud_firewall.clawbot.id]

  user_data = var.enable_cloud_init ? local.rendered_cloud_init : ""

  lifecycle {
    precondition {
      condition     = var.enable_cloud_init ? length(local.rendered_cloud_init) <= 32768 : true
      error_message = "Rendered cloud-init exceeds Hetzner user_data limit (max 32768 chars). Remove optional/custom payload or reduce cloud-init size before applying."
    }

    precondition {
      condition     = !(var.primary_ipv4_enabled && !var.public_ipv4_enabled)
      error_message = "primary_ipv4_enabled requires public_ipv4_enabled to also be true."
    }

    precondition {
      condition     = local.cloud_init_is_valid_yaml
      error_message = "Rendered cloud-init is not valid YAML. Check modules/clawbot_server/cloud-init.tftpl for formatting issues."
    }
  }
}
