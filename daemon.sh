#!/bin/sh
# daemon.sh - Daemon process for periodic synchronization

SCRIPT_DIR=$(dirname "$0")
SCRIPT_PATH="${SCRIPT_DIR}/sync.sh"

# Ensure script is executable
chmod +x "$SCRIPT_PATH" 2>/dev/null

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] DAEMON: $*" >>"${SCRIPT_DIR}/sync.log"
}

log "Daemon process started (PID: $$)"

while true; do
  # Normal sync (respects frequency)
  "$SCRIPT_PATH"
  sleep 60
done
