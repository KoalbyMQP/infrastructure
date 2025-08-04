terraform {
  required_version = ">= 1.12"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

module "server_setup" {
  source = "./modules/server-setup"

  server_ip            = var.server_ip
  ssh_username         = var.ssh_username
  ssh_private_key_path = var.ssh_private_key_path
  ssh_timeout          = var.ssh_timeout
}

module "github_runners" {
  count  = var.enable_github_runners ? 1 : 0
  source = "./modules/github-runners"

  # Depend on server setup completion
  depends_on = [module.server_setup]

  server_ip            = var.server_ip
  ssh_username         = var.ssh_username
  ssh_private_key_path = var.ssh_private_key_path
  ssh_timeout          = var.ssh_timeout

  github_organization = var.github_organization
  github_runner_token = var.github_runner_token
  runner_name         = var.runner_name
  runner_labels       = var.runner_labels
  runner_count        = var.runner_count
  docker_image        = var.docker_image
}
