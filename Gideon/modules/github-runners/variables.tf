variable "server_ip" {
  description = "IP address of the server to install GitHub runners on"
  type        = string
}

variable "ssh_username" {
  description = "SSH username for connecting to the server"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
  sensitive   = true
}

variable "ssh_timeout" {
  description = "SSH connection timeout in seconds"
  type        = number
  default     = 30
}

variable "github_organization" {
  description = "GitHub organization name"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID for runner registration"
  type        = string
}

variable "github_app_private_key_path" {
  description = "Path to the GitHub App private key file (.pem)"
  type        = string
  sensitive   = true
}

variable "runner_configurations" {
  description = "List of runner configurations with different Docker images"
  type = list(object({
    name         = string
    count        = number
    docker_image = string
    labels       = list(string)
  }))
  default = []
}

# Legacy variables for backward compatibility
variable "runner_name" {
  description = "Name for the GitHub runner (deprecated - use runner_configurations)"
  type        = string
  default     = "self-hosted-runner"
}

variable "runner_labels" {
  description = "Labels to assign to the GitHub runner (deprecated - use runner_configurations)"
  type        = list(string)
  default     = ["self-hosted", "linux", "x64"]
}

variable "runner_count" {
  description = "Number of runners to create (max: number of names in names.txt) (deprecated - use runner_configurations)"
  type        = number
  default     = 1

  validation {
    condition     = var.runner_count >= 1
    error_message = "Runner count must be at least 1."
  }
}

variable "docker_image" {
  description = "Docker image to use for GitHub runners (deprecated - use runner_configurations)"
  type        = string
  default     = "myoung34/github-runner:latest"
}
