output "connection_status" {
  description = "Status of SSH connection to server"
  value       = "Connected successfully to ${var.server_ip}"
}

output "server_ip" {
  description = "IP address of the configured server"
  value       = var.server_ip
}

output "ssh_user" {
  description = "SSH username used for connection"
  value       = var.ssh_username
}

output "setup_timestamp" {
  description = "Timestamp when server setup was completed"
  value       = timestamp()
}

output "setup_trigger_hash" {
  description = "Hash of setup script for tracking changes"
  value       = filemd5("${path.module}/../../scripts/basic-server-setup.sh")
  sensitive   = false
}

output "config_files_hash" {
  description = "Combined hash of all configuration files"
  value = {
    docker_daemon = filemd5("${path.module}/../../configs/docker-daemon.json")
    docker_limits = filemd5("${path.module}/../../configs/docker-limits.conf")
    sysctl_config = filemd5("${path.module}/../../configs/sysctl-optimizations.conf")
  }
  sensitive = false
}
