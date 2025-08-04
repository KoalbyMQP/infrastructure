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
