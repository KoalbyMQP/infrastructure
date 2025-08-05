output "runner_status" {
  description = "Status of the GitHub runners"
  value = {
    total_count    = local.total_runners
    organization   = var.github_organization
    configurations = local.configurations
    runner_details = [for runner in local.flattened_runners : {
      name         = runner.runner_name
      config_name  = runner.config_name
      docker_image = runner.docker_image
      labels       = runner.labels
    }]
    server_ip = var.server_ip
  }
}

output "runner_directories" {
  description = "Directories where runners are installed"
  value       = [for runner in local.flattened_runners : "~/github-runners/${runner.runner_name}"]
}

output "docker_images" {
  description = "Docker images being used by runners"
  value       = tolist(local.unique_images)
}
