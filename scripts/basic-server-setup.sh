#!/bin/bash
# scripts/basic-server-setup.sh
# Basic Ubuntu server setup for Docker and infrastructure deployment

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions with enhanced formatting
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING]${NC} $1"
}

step() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] [STEP]${NC} $1"
}

detail() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] [DETAIL]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root (use sudo)"
   exit 1
fi

# Get the SSH username from environment variable, fallback to 'ubuntu'
SSH_USER="${SSH_USERNAME:-ubuntu}"

step "Starting basic Ubuntu server setup"
detail "Running on: $(lsb_release -d | cut -f2) $(uname -m)"
detail "Current user: $(whoami)"
detail "Target user for permissions: ${SSH_USER}"

# Update system packages
step "Updating system packages"
log "Refreshing package index..."
apt-get update -qq
log "Upgrading installed packages..."
apt-get upgrade -y -qq
success "System packages updated successfully"

# Install essential packages
step "Installing essential packages"
log "Installing development and system tools..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    unzip \
    htop \
    vim \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

success "Essential packages installed successfully"

# Install Docker
step "Installing Docker"
if ! command -v docker &> /dev/null; then
    log "Adding Docker's official GPG key..."
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    log "Adding Docker repository..."
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    log "Updating package index with Docker repository..."
    # Update package index
    apt-get update -qq
    
    log "Installing Docker Engine and components..."
    # Install Docker Engine
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    log "Configuring Docker permissions for ${SSH_USER} user..."
    # Add user to docker group
    usermod -aG docker "${SSH_USER}"
    
    log "Starting Docker service..."
    # Start and enable Docker service
    systemctl enable docker
    systemctl start docker
    
    success "Docker installed and configured successfully"
else
    warning "Docker is already installed, skipping installation"
fi

# Verify Docker installation
step "Verifying Docker installation"
detail "Docker version: $(docker --version)"
detail "Docker Compose version: $(docker compose version)"
success "Docker verification completed successfully"

# Configure basic firewall
step "Configuring UFW firewall"
log "Resetting firewall to default settings..."
ufw --force reset
log "Setting default policies (deny incoming, allow outgoing)..."
ufw default deny incoming
ufw default allow outgoing
log "Allowing SSH connections on port 22..."
ufw allow ssh
log "Enabling firewall with current rules..."
ufw --force enable
detail "Firewall rules: SSH (22/tcp) allowed, all other incoming traffic denied"
success "UFW firewall configured successfully"

# Create directory structure for future deployments
step "Creating directory structure"
log "Creating application directories..."
mkdir -p /opt/{docker,scripts,configs}
mkdir -p /var/log/custom
log "Setting directory permissions for ${SSH_USER} user..."
chown -R "${SSH_USER}:${SSH_USER}" /opt/docker
chown -R "${SSH_USER}:${SSH_USER}" /opt/scripts
chown -R "${SSH_USER}:${SSH_USER}" /opt/configs
detail "Created directories: /opt/docker, /opt/scripts, /opt/configs, /var/log/custom"
success "Directory structure created successfully"

# Set system limits for containers
step "Configuring system limits"
log "Installing Docker container limits configuration..."
if [[ -f "/tmp/configs/docker-limits.conf" ]]; then
    cp /tmp/configs/docker-limits.conf /etc/security/limits.d/docker.conf
    detail "Docker limits configuration installed from /tmp/configs/docker-limits.conf"
    success "System limits configured successfully"
else
    error "Docker limits configuration file not found at /tmp/configs/docker-limits.conf"
    exit 1
fi

# Configure Docker daemon
step "Configuring Docker daemon"
log "Installing Docker daemon configuration..."
mkdir -p /etc/docker
if [[ -f "/tmp/configs/docker-daemon.json" ]]; then
    cp /tmp/configs/docker-daemon.json /etc/docker/daemon.json
    detail "Docker daemon configuration installed from /tmp/configs/docker-daemon.json"
    log "Reloading Docker daemon with new configuration..."
    systemctl reload docker
    success "Docker daemon configured successfully"
else
    error "Docker daemon configuration file not found at /tmp/configs/docker-daemon.json"
    exit 1
fi

# System optimization
step "Applying system optimizations"
log "Installing system optimization settings..."
if [[ -f "/tmp/configs/sysctl-optimizations.conf" ]]; then
    cp /tmp/configs/sysctl-optimizations.conf /etc/sysctl.d/99-custom-optimizations.conf
    detail "System optimizations installed from /tmp/configs/sysctl-optimizations.conf"
    log "Applying sysctl settings..."
    sysctl -p /etc/sysctl.d/99-custom-optimizations.conf
    success "System optimizations applied successfully"
else
    error "System optimization configuration file not found at /tmp/configs/sysctl-optimizations.conf"
    exit 1
fi

# Clean up
step "Cleaning up temporary files and packages"
log "Removing unnecessary packages..."
apt-get autoremove -y -qq
log "Cleaning package cache..."
apt-get autoclean -qq
log "Removing temporary configuration files..."
rm -rf /tmp/configs/
rm -f /tmp/basic-server-setup.sh
success "Cleanup completed successfully"

# Final verification
step "Running final verification checks"
log "Gathering system information..."
detail "Operating System: $(lsb_release -d | cut -f2)"
detail "Kernel Version: $(uname -r)"
detail "Docker Version: $(docker --version | cut -d' ' -f3 | cut -d',' -f1)"
detail "Available Disk Space: $(df -h / | awk 'NR==2{print $4}')"
detail "Available Memory: $(free -h | awk 'NR==2{print $7}')"

success "Basic server setup completed successfully!"
log "Server is ready for application deployment"