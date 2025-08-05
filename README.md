# Infrastructure Repository

[![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A5%201.12-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

This repository contains the Infrastructure as Code (IaC) configuration for our server infrastructure, built with [Terraform](https://www.terraform.io). It provides automated provisioning, configuration, and management of our bare metal Ubuntu servers.

## Architecture Overview

Our infrastructure is organized into modular components:

- **Server Setup** - Base server configuration and SSH connectivity
- **PXE Server** - Network boot server configuration
- **GitHub Runners** - Self-hosted GitHub Actions runners

## Prerequisites

Before getting started, ensure you have:

- [Terraform](https://www.terraform.io/downloads) >= 1.12 installed
- SSH access to your target server(s)
- A valid SSH private key
- Network connectivity to your infrastructure

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/KoalbyMQP/infra.git
cd infra
```

### 2. Configure Variables
Create a `terraform.tfvars` file with your configuration:

```hcl
server_ip            = "192.168.1.100"
ssh_username         = "ubuntu"
ssh_private_key_path = "~/.ssh/id_rsa"
ssh_timeout          = 30

# GitHub Runners (optional)
enable_github_runners = true
github_organization   = "KoalbyMQP"

# GitHub App authentication
github_app_id                 = "123456"
github_app_private_key_path   = "~/.ssh/keys/github-app-private-key.pem"

runner_name           = "server-runner"
runner_count          = 2
runner_labels         = ["self-hosted", "linux", "x64", "docker"]
```

### 3. Initialize and Deploy
```bash
# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the configuration
terraform apply
```

## Project Structure

```
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Variable definitions
├── terraform.tfvars        # Variable values (create this)
├── modules/
│   ├── server-setup/       # Base server configuration
│   ├── pxe-server/         # PXE boot server setup
│   └── github-runners/     # GitHub Actions runners
├── configs/                # Configuration files
│   ├── docker-daemon.json
│   ├── docker-limits.conf
│   └── sysctl-optimizations.conf
└── scripts/                # Setup scripts
    └── basic-server-setup.sh
```

## Configuration

### Required Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `server_ip` | IP address of the target server | `string` | - |
| `ssh_username` | SSH username for server access | `string` | `ubuntu` |
| `ssh_private_key_path` | Path to SSH private key | `string` | `~/.ssh/id_rsa` |
| `ssh_timeout` | SSH connection timeout (seconds) | `number` | `30` |

### GitHub Runner Variables (Optional)

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `enable_github_runners` | Enable GitHub runners setup | `bool` | `false` |
| `github_organization` | GitHub organization name | `string` | `""` |
| `github_app_id` | GitHub App ID | `string` | - |
| `github_app_private_key_path` | Path to GitHub App private key (.pem) | `string` | - |
| `runner_name` | Base name for runners | `string` | `server-runner` |
| `runner_count` | Number of runners to create | `number` | `1` |
| `runner_labels` | Labels for runners | `list(string)` | `["self-hosted", "linux", "x64"]` |

## Development

### Working with Modules

Each module is self-contained and can be developed independently:

```bash
# Test a specific module
cd modules/server-setup
terraform init
terraform plan
```

### Best Practices

- Always run `terraform plan` before applying changes
- Use meaningful commit messages for infrastructure changes
- Test changes in a development environment first
- Keep sensitive values in `terraform.tfvars` (not in version control)

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [HashiCorp Configuration Language](https://www.terraform.io/docs/language/index.html)

---

Built with ❤️ for [Terraform](https://www.terraform.io)
