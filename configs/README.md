# Configuration Files

This directory contains configuration files that are deployed to the server during the setup process.

## Files

### `docker-daemon.json`
Docker daemon configuration file that sets:
- Log rotation settings (100MB max, 3 files)
- Storage driver (overlay2)
- Default ulimits for containers
- BuildKit feature enablement

**Deployed to:** `/etc/docker/daemon.json`

### `docker-limits.conf`
System limits configuration for Docker containers:
- File descriptor limits (65536 soft/hard)
- Process limits (32768 soft/hard)

**Deployed to:** `/etc/security/limits.d/docker.conf`

### `sysctl-optimizations.conf`
System kernel parameter optimizations:
- File watcher limits for development
- Network performance tuning
- Virtual memory settings for containers

**Deployed to:** `/etc/sysctl.d/99-custom-optimizations.conf`

## Usage

These files are automatically copied to the server by Terraform during the provisioning process and applied by the `basic-server-setup.sh` script.

## Maintenance

When modifying these configuration files, Terraform will detect the changes and re-run the provisioning process on the next `terraform apply`.
