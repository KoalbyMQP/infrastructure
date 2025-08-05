terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
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
  count = var.runner_count

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
      "mkdir -p $HOME/github-runners/runner-${count.index + 1}",
      "chmod 755 $HOME/github-runners/runner-${count.index + 1}"
    ]
  }
}

# Pull Docker image
resource "docker_image" "github_runner" {
  name         = var.docker_image
  keep_locally = false
}

# Create GitHub runner containers
resource "docker_container" "github_runner" {
  count = var.runner_count

  depends_on = [
    null_resource.runner_directories,
    docker_image.github_runner
  ]

  name  = "github-runner-${count.index + 1}"
  image = docker_image.github_runner.image_id

  restart = "unless-stopped"

  env = [
    "RUNNER_NAME=${var.runner_name}-${count.index + 1}",
    "APP_ID=${var.github_app_id}",
    "APP_LOGIN=${var.github_organization}",
    "ORG_NAME=${var.github_organization}",
    "APP_PRIVATE_KEY=${file(var.github_app_private_key_path)}",
    "RUNNER_WORKDIR=/tmp/runner/work",
    "RUNNER_GROUP=gideon",
    "LABELS=${join(",", var.runner_labels)}",
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
    source = "/home/${var.ssh_username}/github-runners/runner-${count.index + 1}"
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
