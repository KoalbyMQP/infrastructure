#!/bin/bash
set -euo pipefail

# Simple log function to pull from git 
log() { echo -e "[INFO] $(date +'%Y-%m-%d %H:%M:%S') $1"; }

cd /home/lab || exit 1

log "Pulling latest repo..."
git pull

log "Update complete!"
