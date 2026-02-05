#!/bin/bash

# ===== REQUIRE SUDO =====
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: This script must be run with sudo or as root."
  echo "Usage: sudo $0"
  exit 1
fi

# ===== CONFIG =====
SERVER_NAME="Gideon"
COUNTDOWN=5  # minutes before shutdown
WEBHOOK_URL="$SLACK_WEBHOOK_URL"  # Must be set in your environment

# ===== CHECKS =====
if [ -z "$WEBHOOK_URL" ]; then
  echo "ERROR: SLACK_WEBHOOK_URL environment variable is not set."
  echo "Set it using: sudo nano /etc/environment"
  exit 1
fi

# ===== FUNCTIONS =====
send_slack_message() {
  local message="$1"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S %Z")
  
  curl -s -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\":warning: [$timestamp] $message\"}" \
    "$WEBHOOK_URL" > /dev/null
}

# ===== MAIN =====
send_slack_message "$SERVER_NAME will shut down for maintenance in $COUNTDOWN minutes. Please save your work."

echo "Notified Slack. Waiting $COUNTDOWN minutes..."
sleep $((COUNTDOWN * 60))

send_slack_message "$SERVER_NAME is shutting down now."
shutdown -h now
