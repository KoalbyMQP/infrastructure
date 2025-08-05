output "runner_status" {
  description = "Status of the GitHub runners"
  value = {
    count        = var.runner_count
    organization = var.github_organization
    runner_names = [for i in range(var.runner_count) : local.runner_names[i]]
    labels       = var.runner_labels
    server_ip    = var.server_ip
  }
}

output "runner_directories" {
  description = "Directories where runners are installed"
  value       = [for i in range(var.runner_count) : "~/github-runners/${local.runner_names[i]}"]
}
