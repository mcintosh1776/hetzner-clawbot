variable "name" {
  type        = string
  description = "Hetzner private network name."
}

variable "ip_range" {
  type        = string
  description = "Top-level private network CIDR."
}

variable "subnet_ip_range" {
  type        = string
  description = "Subnet CIDR carved from ip_range for cloud servers."
}

variable "network_zone" {
  type        = string
  description = "Hetzner network zone for the subnet."
}
