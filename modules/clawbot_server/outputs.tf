output "server_id" {
  value       = hcloud_server.clawbot.id
  description = "Hetzner ID for the clawbot server."
}

output "server_name" {
  value       = hcloud_server.clawbot.name
  description = "Server name."
}

output "ipv4_address" {
  value       = hcloud_server.clawbot.ipv4_address
  description = "Public IPv4 address."
}

output "private_ipv4_address" {
  value       = var.private_network_ip != "" ? var.private_network_ip : null
  description = "Private IPv4 address on the attached Hetzner private network, if configured."
}
