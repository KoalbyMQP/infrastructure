terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Read the names from the names.txt file
locals {
  runner_names = split("\n", trimspace(file("${path.module}/names.txt")))

  # Determine which configuration to use (new multiple configs or legacy single config)
  use_multiple_configs = length(var.runner_configurations) > 0

  # Create configurations list - either from new variable or legacy variables
  configurations = local.use_multiple_configs ? var.runner_configurations : [
    {
      name         = var.runner_name
      count        = var.runner_count
      docker_image = var.docker_image
      labels       = var.runner_labels
    }
  ]

  # Calculate total runners needed and flatten configurations
  flattened_runners = flatten([
    for config_idx, config in local.configurations : [
      for runner_idx in range(config.count) : {
        config_name  = config.name
        runner_name  = "${local.runner_names[config_idx == 0 ? runner_idx : sum([for prev_config in slice(local.configurations, 0, config_idx) : prev_config.count]) + runner_idx]}"
        docker_image = config.docker_image
        labels       = config.labels
        global_index = config_idx == 0 ? runner_idx : sum([for prev_config in slice(local.configurations, 0, config_idx) : prev_config.count]) + runner_idx
      }
    ]
  ])

  total_runners = sum([for config in local.configurations : config.count])
}

# Validate that we don't try to create more runners than we have names
locals {
  validation = local.total_runners <= length(local.runner_names) ? true : tobool("Error: total runners (${local.total_runners}) exceeds available names (${length(local.runner_names)})")
}

# Copy GitHub App private key to remote host
resource "null_resource" "github_app_key_setup" {
  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  # Create base github-runners directory and copy private key
  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/github-runners",
      "chmod 700 $HOME/github-runners"
    ]
  }

  provisioner "file" {
    source      = var.github_app_private_key_path
    destination = "/home/${var.ssh_username}/github-runners/app-private-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 $HOME/github-runners/app-private-key.pem"
    ]
  }

  triggers = {
    app_id = var.github_app_id
  }
}

# Create individual runner directories
resource "null_resource" "runner_directories" {
  count = local.total_runners

  depends_on = [null_resource.github_app_key_setup]

  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p $HOME/github-runners/${local.flattened_runners[count.index].runner_name}",
      "chmod 755 $HOME/github-runners/${local.flattened_runners[count.index].runner_name}",
      "ls -la $HOME/github-runners/${local.flattened_runners[count.index].runner_name}"
    ]
  }

  # Trigger recreation if runner names change
  triggers = {
    runner_name = local.flattened_runners[count.index].runner_name
    server_ip   = var.server_ip
  }
}

# Verify directories exist before creating containers
resource "null_resource" "verify_directories" {
  count = local.total_runners

  depends_on = [null_resource.runner_directories]

  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  provisioner "remote-exec" {
    inline = [
      "test -d $HOME/github-runners/${local.flattened_runners[count.index].runner_name} || exit 1",
      "echo 'Directory verified: $HOME/github-runners/${local.flattened_runners[count.index].runner_name}'"
    ]
  }

  triggers = {
    runner_name = local.flattened_runners[count.index].runner_name
  }
}

# Pull Docker images for each unique image using null_resource for better control
locals {
  unique_images = toset([for runner in local.flattened_runners : runner.docker_image])
}

# Pre-pull images using null_resource for better error handling and retry logic
resource "null_resource" "pull_docker_images" {
  for_each = local.unique_images

  depends_on = [null_resource.github_app_key_setup]

  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Pulling Docker image: ${each.value}'",
      "if ! timeout 300 docker pull ${each.value}; then",
      "  echo 'First pull attempt failed, retrying after 10 seconds...'",
      "  sleep 10",
      "  if ! timeout 300 docker pull ${each.value}; then",
      "    echo 'Second pull attempt failed, exiting...'",
      "    exit 1",
      "  fi",
      "fi",
      "echo 'Successfully pulled image: ${each.value}'",
      "docker images --format 'table {{.Repository}}:{{.Tag}}\\t{{.Size}}\\t{{.CreatedAt}}' | grep '${split(":", each.value)[0]}' || echo 'Image verification completed'"
    ]
  }

  triggers = {
    image = each.value
  }
}

resource "docker_image" "github_runner" {
  for_each = local.unique_images

  depends_on = [null_resource.pull_docker_images]

  name         = each.value
  keep_locally = false

  # Force pull to ensure we get the latest version
  pull_triggers = [null_resource.pull_docker_images[each.value].id]
}

# Create GitHub runner containers
resource "docker_container" "github_runner" {
  count = local.total_runners

  depends_on = [
    null_resource.verify_directories,
    null_resource.pull_docker_images,
    docker_image.github_runner
  ]

  name  = local.flattened_runners[count.index].runner_name
  image = docker_image.github_runner[local.flattened_runners[count.index].docker_image].image_id

  restart = "unless-stopped"

  # Run ZaraOS builder containers as root to fix permission issues
  user = local.flattened_runners[count.index].docker_image == "ghcr.io/koalbymqp/zaraos-builder:latest" ? "0:0" : null

  env = [
    "RUNNER_NAME=${local.flattened_runners[count.index].runner_name}",
    "APP_ID=${var.github_app_id}",
    "APP_LOGIN=${var.github_organization}",
    "ORG_NAME=${var.github_organization}",
    "APP_PRIVATE_KEY=${file(var.github_app_private_key_path)}",
    "RUNNER_WORKDIR=/tmp/runner/work",
    "RUNNER_GROUP=gideon",
    "LABELS=${join(",", local.flattened_runners[count.index].labels)}",
    "RUNNER_SCOPE=org",
    "DISABLE_AUTO_UPDATE=true"
  ]

  # Mount Docker socket for Docker-in-Docker
  mounts {
    source = "/var/run/docker.sock"
    target = "/var/run/docker.sock"
    type   = "bind"
  }

  # Mount runner work directory
  mounts {
    source = "/home/${var.ssh_username}/github-runners/${local.flattened_runners[count.index].runner_name}"
    target = "/tmp/runner"
    type   = "bind"
  }

  # Health check to ensure container is running properly
  healthcheck {
    test         = ["CMD", "pgrep", "-f", "Runner.Listener"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }
}
