variable "env" {
  type        = string
  description = "Deployment environment label for naming and tagging."
}

variable "name" {
  type        = string
  description = "Hetzner server name (e.g. clawbot-prod-1)."
}

variable "server_type" {
  type        = string
  description = "Hetzner server type."
  default     = "cpx22"
}

variable "location" {
  type        = string
  description = "Hetzner location (for example: ash, hil, fsn1)."
}

variable "ssh_keys" {
  type        = list(string)
  description = "Public key names already imported into Hetzner."
}

variable "ssh_public_keys" {
  type        = map(string)
  description = "Optional map of SSH key names to public key material managed by Terraform."
  default     = {}
}

variable "role" {
  type        = string
  description = "Server role label for resource tags."
  default     = "clawbot"
}

variable "firewall_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach SSH (22). Empty means no inbound SSH."
  default     = []
}

variable "public_ipv4_enabled" {
  type        = bool
  description = "Whether to enable public IPv4."
  default     = true
}

variable "public_ipv6_enabled" {
  type        = bool
  description = "Whether to enable public IPv6."
  default     = true
}

variable "bootstrap_users" {
  type        = list(string)
  description = "Non-root users created by cloud-init."
  default     = ["clawbot"]

  validation {
    condition     = length(var.bootstrap_users) > 0
    error_message = "At least one bootstrap user must be provided."
  }
}

variable "bootstrap_user_ssh_public_keys" {
  type        = map(list(string))
  description = "Optional SSH public keys to attach to bootstrap users."
  default     = {}
}

variable "enable_cloud_init" {
  type        = bool
  description = "Enable default cloud-init bootstrap configuration."
  default     = true
}

variable "enable_root_ssh" {
  type        = bool
  description = "Whether to allow SSH access for the root user."
  default     = false
}

variable "cloud_init" {
  type        = string
  description = "Optional override for cloud-init data."
  default     = ""
}

variable "openclaw_repo_url" {
  type        = string
  description = "OpenClaw Git repository URL to clone under /srv/openclaw during cloud-init."
  default     = "https://github.com/openclaw/openclaw.git"
}

variable "openclaw_gateway_token" {
  type        = string
  description = "Optional fixed OPENCLAW_GATEWAY_TOKEN to persist across rebuilds."
  default     = ""
  sensitive   = true
}

variable "opt_volume_enabled" {
  type        = bool
  description = "Whether to attach and mount a persistent /opt data volume."
  default     = true
}

variable "opt_volume_size_gb" {
  type        = number
  description = "Persistent /opt volume size in GiB."
  default     = 10

  validation {
    condition     = var.opt_volume_size_gb > 0
    error_message = "opt_volume_size_gb must be greater than 0."
  }
}

variable "opt_volume_fstype" {
  type        = string
  description = "Filesystem type for the persistent /opt volume."
  default     = "ext4"
}
