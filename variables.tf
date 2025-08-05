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

# GitHub Runner Variables
variable "github_organization" {
  description = "GitHub organization name (e.g., KoalbyMQP)"
  type        = string
  default     = ""
}

variable "github_app_id" {
  description = "GitHub App ID for runner registration"
  type        = string
}

variable "github_app_private_key_path" {
  description = "Path to the GitHub App private key file (.pem)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.github_app_private_key_path) > 0 && can(regex("\\.pem$", var.github_app_private_key_path))
    error_message = "GitHub App private key path must end with .pem."
  }
}

variable "runner_name" {
  description = "Base name for GitHub runners"
  type        = string
  default     = "server-runner"
}

variable "runner_labels" {
  description = "Labels to assign to GitHub runners"
  type        = list(string)
  default     = ["self-hosted", "linux", "x64"]
}

variable "runner_count" {
  description = "Number of GitHub runners to create"
  type        = number
  default     = 1

  validation {
    condition     = var.runner_count >= 1 && var.runner_count <= 10
    error_message = "Runner count must be between 1 and 10."
  }
}

variable "enable_github_runners" {
  description = "Whether to enable GitHub runners setup"
  type        = bool
  default     = false
}

variable "docker_image" {
  description = "Docker image to use for GitHub runners"
  type        = string
  default     = "myoung34/github-runner:latest"
}
