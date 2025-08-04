resource "null_resource" "github_runner_setup" {
  count = var.runner_count

  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  # Create runner directories and setup
  provisioner "remote-exec" {
    inline = [
      "echo -e '\\033[0;34m[INFO]\\033[0m Setting up containerized GitHub Actions Runner ${count.index + 1}'",
      "mkdir -p ~/github-runners/runner-${count.index + 1}",
      "cd ~/github-runners/runner-${count.index + 1}",
      "echo -e '\\033[0;32m[SUCCESS]\\033[0m Runner directory created'"
    ]
  }

  # Pull Docker image
  provisioner "remote-exec" {
    inline = [
      "echo -e '\\033[0;34m[INFO]\\033[0m Pulling Docker image: ${var.docker_image}'",
      "docker pull ${var.docker_image}",
      "echo -e '\\033[0;32m[SUCCESS]\\033[0m Docker image pulled'"
    ]
  }

  # Start containerized GitHub runner
  provisioner "remote-exec" {
    inline = [
      "echo -e '\\033[0;34m[INFO]\\033[0m Starting containerized GitHub Runner ${count.index + 1}'",
      "docker run -d \\",
      "  --name github-runner-${count.index + 1} \\",
      "  --restart unless-stopped \\",
      "  -e REPO_URL=https://github.com/${var.github_organization} \\",
      "  -e RUNNER_NAME=${var.runner_name}-${count.index + 1} \\",
      "  -e RUNNER_TOKEN=${var.github_runner_token} \\",
      "  -e RUNNER_WORKDIR=/tmp/runner/work \\",
      "  -e RUNNER_GROUP=default \\",
      "  -e LABELS=${join(",", var.runner_labels)} \\",
      "  -v /var/run/docker.sock:/var/run/docker.sock \\",
      "  -v ~/github-runners/runner-${count.index + 1}:/tmp/runner \\",
      "  ${var.docker_image}",
      "echo -e '\\033[0;32m[SUCCESS]\\033[0m GitHub Actions Runner ${count.index + 1} container started'"
    ]
  }

  # Wait for runner to register and verify
  provisioner "remote-exec" {
    inline = [
      "echo -e '\\033[0;34m[INFO]\\033[0m Waiting for runner ${count.index + 1} to register...'",
      "sleep 10",
      "docker logs github-runner-${count.index + 1} | tail -5",
      "echo -e '\\033[0;32m[SUCCESS]\\033[0m Runner ${count.index + 1} setup complete'"
    ]
  }

  # Trigger recreation if token or image changes
  triggers = {
    runner_token = var.github_runner_token
    docker_image = var.docker_image
  }
}
