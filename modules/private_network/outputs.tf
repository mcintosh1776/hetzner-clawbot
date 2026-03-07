output "network_id" {
  value       = hcloud_network.this.id
  description = "Hetzner private network ID."
}

output "network_name" {
  value       = hcloud_network.this.name
  description = "Hetzner private network name."
}

output "subnet_ip_range" {
  value       = hcloud_network_subnet.this.ip_range
  description = "Private subnet CIDR."
}
