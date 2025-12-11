#!/bin/sh
# uninstall-cron.sh - Remove cron job for synchronization

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SCRIPT="${SCRIPT_DIR}/sync.sh"

# Remove cron entries containing the script path
crontab -l 2>/dev/null | grep -v "$SCRIPT" | crontab -

if [ $? -eq 0 ]; then
  echo "Cron job uninstalled successfully"
else
  echo "Failed to uninstall cron job"
  exit 1
fi
