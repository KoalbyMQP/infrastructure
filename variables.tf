variable "server_ip" {
  description = "IP address of the bare metal Ubuntu server"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.server_ip))
    error_message = "Server IP must be a valid IPv4 address (e.g., 192.168.1.10)."
  }
}

variable "ssh_username" {
  description = "SSH username for connecting to the server"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = length(var.ssh_username) > 0 && length(var.ssh_username) <= 32
    error_message = "SSH username must be between 1 and 32 characters long."
  }
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file for server authentication"
  type        = string
  default     = "~/.ssh/id_rsa"
  sensitive   = true

  validation {
    condition     = length(var.ssh_private_key_path) > 0
    error_message = "SSH private key path cannot be empty."
  }
}

variable "ssh_timeout" {
  description = "SSH connection timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.ssh_timeout >= 10 && var.ssh_timeout <= 300
    error_message = "SSH timeout must be between 10 and 300 seconds."
  }
}