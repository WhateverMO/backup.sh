#!/bin/sh
# install-cron.sh - Install cron job for synchronization

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
LOG_FILE="${SCRIPT_DIR}/sync.log"
SCRIPT="${SCRIPT_DIR}/sync.sh"

# Check if script exists
if [ ! -f "$SCRIPT" ]; then
  echo "Error: sync.sh not found in $SCRIPT_DIR"
  exit 1
fi

# Create cron entry (normal sync, respects frequency)
CRON_ENTRY="* * * * * cd '$SCRIPT_DIR' && '$SCRIPT' >> '$LOG_FILE' 2>&1"

# Check if already installed
if crontab -l 2>/dev/null | grep -F "$SCRIPT" >/dev/null; then
  echo "Cron job already installed"
  exit 0
fi

# Add to crontab
(
  crontab -l 2>/dev/null
  echo "$CRON_ENTRY"
) | crontab -

if [ $? -eq 0 ]; then
  echo "Cron job installed successfully"
  echo "Note: Sync will respect frequency settings in sync.conf"
  echo "Use './sync.sh --force' to sync all tasks immediately"
else
  echo "Failed to install cron job"
  exit 1
fi
