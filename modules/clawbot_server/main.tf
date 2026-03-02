terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

locals {
  bootstrap_runner_script = file("${path.module}/bootstrap-node-runner.sh")
  rendered_cloud_init = trimspace(var.cloud_init) != "" ? var.cloud_init : templatefile(
    "${path.module}/cloud-init.tftpl",
    {
      users                    = var.bootstrap_users
      user_ssh_authorized_keys = var.bootstrap_user_ssh_public_keys
      enable_root_ssh          = var.enable_root_ssh
      openclaw_repo_url        = var.openclaw_repo_url
      openclaw_gateway_token   = var.openclaw_gateway_token
      bootstrap_runner_script  = local.bootstrap_runner_script
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

resource "hcloud_server" "clawbot" {
  name        = var.name
  image       = "ubuntu-24.04"
  server_type = var.server_type
  location    = var.location

  public_net {
    ipv4_enabled = var.public_ipv4_enabled
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
      condition     = local.cloud_init_is_valid_yaml
      error_message = "Rendered cloud-init is not valid YAML. Check modules/clawbot_server/cloud-init.tftpl for formatting issues."
    }
  }
}
