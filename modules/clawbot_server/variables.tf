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

variable "private_network_id" {
  type        = string
  description = "Optional Hetzner private network ID to attach the server to."
  default     = ""
}

variable "private_network_ip" {
  type        = string
  description = "Optional static private IPv4 address to assign on the Hetzner private network."
  default     = ""
}

variable "private_runtime_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach private runtime listener ports."
  default     = []
}

variable "private_runtime_ingress_ports" {
  type        = list(number)
  description = "Private runtime listener ports that should be opened to private_runtime_ingress_cidrs."
  default     = []
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

variable "openclaw_bootstrap_runner_url" {
  type        = string
  description = "Publicly reachable URL of the bootstrap runner script downloaded during cloud-init. The host must be able to access this URL without private authentication."
  default     = ""
}

variable "openclaw_bootstrap_runner_sha256" {
  type        = string
  description = "Optional SHA-256 hash for the bootstrap runner script fetched during cloud-init. When set, the downloaded or cached runner must match before it is executed as root."
  default     = ""

  validation {
    condition     = var.openclaw_bootstrap_runner_sha256 == "" || can(regex("^[A-Fa-f0-9]{64}$", var.openclaw_bootstrap_runner_sha256))
    error_message = "openclaw_bootstrap_runner_sha256 must be empty or a 64-character hexadecimal SHA-256 digest."
  }
}

variable "openclaw_public_hostname" {
  type        = string
  description = "Public hostname for OpenClaw webhook/Reverse-proxy ingress (for example, agents.example.com)."
  default     = ""
}

variable "openclaw_letsencrypt_email" {
  type        = string
  description = "Email address used for Let's Encrypt certificate registration."
  default     = ""
  sensitive   = true
}

variable "openclaw_enable_webhook_proxy" {
  type        = bool
  description = "Enable Nginx+Let's Encrypt webhook proxy setup in bootstrap."
  default     = false
}

variable "openclaw_enable_gateway" {
  type        = bool
  description = "Enable the shared OpenClaw gateway/control-plane container on this host."
  default     = true
}

variable "openclaw_private_runtime_public_ids" {
  type        = list(string)
  description = "Public bot IDs whose private runtimes should run on this host."
  default     = ["bob", "stacks", "jennifer", "steve", "number5"]
}

variable "openclaw_private_runtime_bind_host" {
  type        = string
  description = "Host IP used when publishing private runtime container ports."
  default     = "127.0.0.1"
}

variable "openclaw_remote_runtime_urls" {
  type        = map(string)
  description = "Optional map of public bot IDs to remote runtime URLs used by the ingress relay."
  default     = {}
}

variable "openclaw_webhook_receiver_port" {
  type        = number
  description = "Local port for the Telegram webhook receiver daemon."
  default     = 9000

  validation {
    condition     = var.openclaw_webhook_receiver_port > 0 && var.openclaw_webhook_receiver_port <= 65535
    error_message = "openclaw_webhook_receiver_port must be in the range 1-65535."
  }
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
  default     = "xfs"
}
