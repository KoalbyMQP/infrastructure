# server-setup

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.server_connection_test](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.server_setup](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_server_ip"></a> [server\_ip](#input\_server\_ip) | IP address of the target server | `string` | n/a | yes |
| <a name="input_setup_mode"></a> [setup\_mode](#input\_setup\_mode) | Server setup mode: basic, full, or minimal | `string` | `"basic"` | no |
| <a name="input_ssh_private_key_path"></a> [ssh\_private\_key\_path](#input\_ssh\_private\_key\_path) | Path to SSH private key file | `string` | `"~/.ssh/id_rsa"` | no |
| <a name="input_ssh_timeout"></a> [ssh\_timeout](#input\_ssh\_timeout) | SSH connection timeout in seconds | `number` | `30` | no |
| <a name="input_ssh_username"></a> [ssh\_username](#input\_ssh\_username) | SSH username for server connection | `string` | `"ubuntu"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_files_hash"></a> [config\_files\_hash](#output\_config\_files\_hash) | Combined hash of all configuration files |
| <a name="output_connection_status"></a> [connection\_status](#output\_connection\_status) | Status of SSH connection to server |
| <a name="output_server_ip"></a> [server\_ip](#output\_server\_ip) | IP address of the configured server |
| <a name="output_setup_timestamp"></a> [setup\_timestamp](#output\_setup\_timestamp) | Timestamp when server setup was completed |
| <a name="output_setup_trigger_hash"></a> [setup\_trigger\_hash](#output\_setup\_trigger\_hash) | Hash of setup script for tracking changes |
| <a name="output_ssh_user"></a> [ssh\_user](#output\_ssh\_user) | SSH username used for connection |
<!-- END_TF_DOCS -->
