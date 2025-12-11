#!/bin/sh
# daemon.sh - Daemon process for periodic synchronization

SCRIPT_DIR=$(dirname "$0")
SCRIPT_PATH="${SCRIPT_DIR}/sync.sh"

# Ensure script is executable
chmod +x "$SCRIPT_PATH" 2>/dev/null

while true; do
  "$SCRIPT_PATH"
  sleep 60
done
