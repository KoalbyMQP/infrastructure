# github-runners

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_docker"></a> [docker](#provider\_docker) | 3.6.2 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [docker_container.github_runner](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container) | resource |
| [docker_image.github_runner](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/image) | resource |
| [null_resource.github_app_key_setup](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.runner_directories](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_docker_image"></a> [docker\_image](#input\_docker\_image) | Docker image to use for GitHub runners | `string` | `"myoung34/github-runner:latest"` | no |
| <a name="input_github_app_id"></a> [github\_app\_id](#input\_github\_app\_id) | GitHub App ID for runner registration | `string` | n/a | yes |
| <a name="input_github_app_private_key_path"></a> [github\_app\_private\_key\_path](#input\_github\_app\_private\_key\_path) | Path to the GitHub App private key file (.pem) | `string` | n/a | yes |
| <a name="input_github_organization"></a> [github\_organization](#input\_github\_organization) | GitHub organization name | `string` | n/a | yes |
| <a name="input_runner_count"></a> [runner\_count](#input\_runner\_count) | Number of runners to create | `number` | `1` | no |
| <a name="input_runner_labels"></a> [runner\_labels](#input\_runner\_labels) | Labels to assign to the GitHub runner | `list(string)` | <pre>[<br/>  "self-hosted",<br/>  "linux",<br/>  "x64"<br/>]</pre> | no |
| <a name="input_runner_name"></a> [runner\_name](#input\_runner\_name) | Name for the GitHub runner | `string` | `"self-hosted-runner"` | no |
| <a name="input_server_ip"></a> [server\_ip](#input\_server\_ip) | IP address of the server to install GitHub runners on | `string` | n/a | yes |
| <a name="input_ssh_private_key_path"></a> [ssh\_private\_key\_path](#input\_ssh\_private\_key\_path) | Path to the SSH private key file | `string` | n/a | yes |
| <a name="input_ssh_timeout"></a> [ssh\_timeout](#input\_ssh\_timeout) | SSH connection timeout in seconds | `number` | `30` | no |
| <a name="input_ssh_username"></a> [ssh\_username](#input\_ssh\_username) | SSH username for connecting to the server | `string` | `"ubuntu"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_runner_directories"></a> [runner\_directories](#output\_runner\_directories) | Directories where runners are installed |
| <a name="output_runner_status"></a> [runner\_status](#output\_runner\_status) | Status of the GitHub runners |
<!-- END_TF_DOCS -->
