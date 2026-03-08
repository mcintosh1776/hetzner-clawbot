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

