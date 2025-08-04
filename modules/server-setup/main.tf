resource "null_resource" "server_connection_test" {
  # SSH connection configuration
  connection {
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  # Test connection with simple command
  provisioner "remote-exec" {
    inline = [
      "echo -e '\\033[0;34m[INFO]\\033[0m Testing SSH connection to ${var.server_ip}'",
      "echo -e '\\033[0;36m[DETAIL]\\033[0m Connected as: $(whoami)'",
      "echo -e '\\033[0;36m[DETAIL]\\033[0m Server hostname: $(hostname)'",
      "echo -e '\\033[0;36m[DETAIL]\\033[0m Server uptime: $(uptime)'",
      "echo -e '\\033[0;32m[SUCCESS]\\033[0m SSH connection established successfully'"
    ]
  }
}

# This creates a "fake" resource that exists only in Terraform state
resource "null_resource" "server_setup" {
  # Depends on successful connection test
  depends_on = [null_resource.server_connection_test]

  connection { # This tells Terraform HOW to connect to our real server
    type        = "ssh"
    host        = var.server_ip
    user        = var.ssh_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "${var.ssh_timeout}s"
  }

  # Copy setup script to server
  provisioner "file" {
    source      = "${path.root}/scripts/basic-server-setup.sh"
    destination = "/tmp/basic-server-setup.sh"
  }

  # Copy configuration files to server
  provisioner "file" {
    source      = "${path.root}/configs"
    destination = "/tmp"
  }

  # Execute setup script
  provisioner "remote-exec" {
    inline = [
      "echo -e '\\033[1;33m[INIT]\\033[0m Starting server setup process'",
      "chmod +x /tmp/basic-server-setup.sh",
      "export SSH_USERNAME='${var.ssh_username}'",
      "sudo -E /tmp/basic-server-setup.sh",
      "echo -e '\\033[0;32m[COMPLETE]\\033[0m Server setup completed successfully'"
    ]
  }

  # Trigger re-run if script or config files change
  triggers = {
    script_hash        = filemd5("${path.root}/scripts/basic-server-setup.sh")
    docker_daemon_hash = filemd5("${path.root}/configs/docker-daemon.json")
    docker_limits_hash = filemd5("${path.root}/configs/docker-limits.conf")
    sysctl_config_hash = filemd5("${path.root}/configs/sysctl-optimizations.conf")
    server_ip          = var.server_ip
  }
}
