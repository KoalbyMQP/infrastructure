variable "server_ip" {
  description = "IP address of the target server"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.server_ip))
    error_message = "Server IP must be a valid IPv4 address."
  }
}

variable "ssh_username" {
  description = "SSH username for server connection"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = length(var.ssh_username) > 0
    error_message = "SSH username cannot be empty."
  }
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
  sensitive   = true

  validation {
    condition     = can(file(var.ssh_private_key_path))
    error_message = "SSH private key file must exist and be readable."
  }
}

variable "ssh_timeout" {
  description = "SSH connection timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.ssh_timeout > 0 && var.ssh_timeout <= 600
    error_message = "SSH timeout must be between 1 and 600 seconds."
  }
}

variable "setup_mode" {
  description = "Server setup mode: basic, full, or minimal"
  type        = string
  default     = "basic"

  validation {
    condition     = contains(["basic", "full", "minimal"], var.setup_mode)
    error_message = "Setup mode must be one of: basic, full, minimal."
  }
}
