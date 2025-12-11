#!/bin/sh
# sync.sh - Minimal folder synchronization script

# Initialize paths
SCRIPT_DIR=$(dirname "$0")
CONFIG_FILE="${SCRIPT_DIR}/sync.conf"
STATE_DIR="${SCRIPT_DIR}/.sync_state"
LOG_FILE="${SCRIPT_DIR}/sync.log"
DATA_DIR="${SCRIPT_DIR}/data"

# Ensure required directories exist
mkdir -p "$STATE_DIR" "$DATA_DIR" 2>/dev/null

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOG_FILE"
}

# Portable stat function
get_file_mtime() {
  file="$1"
  # Try BSD stat (macOS)
  if stat -f %m "$file" 2>/dev/null; then
    return
  fi
  # Try GNU stat
  if stat -c %Y "$file" 2>/dev/null; then
    return
  fi
  # Try ls as fallback
  ls -l "$file" | awk '{print $6, $7, $8}' | date -jf "%b %d %H:%M" +%s 2>/dev/null || echo "0"
}

get_file_size() {
  file="$1"
  # Try BSD stat (macOS)
  if stat -f %z "$file" 2>/dev/null; then
    return
  fi
  # Try GNU stat
  if stat -c %s "$file" 2>/dev/null; then
    return
  fi
  # Try wc as fallback
  wc -c <"$file" 2>/dev/null || echo "0"
}

# Resolve destination path
resolve_destination() {
  dest="$1"
  case "$dest" in
  /*)
    # Absolute path
    echo "$dest"
    ;;
  *)
    # Relative path
    echo "${DATA_DIR}/${dest}"
    ;;
  esac
}

# Main synchronization function
sync_folder() {
  src="$1"
  dest="$2"
  frequency="$3"

  # Resolve destination path
  dest=$(resolve_destination "$dest")

  # Create destination directory if needed
  mkdir -p "$dest" 2>/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR: Cannot create destination directory - $dest"
    return 1
  fi

  # Get state file path
  # Use a sanitized name for the state file
  safe_src=$(echo "$src" | sed 's/[^a-zA-Z0-9]/_/g')
  state_file="${STATE_DIR}/${safe_src}_to_$(echo "$dest" | sed 's/[^a-zA-Z0-9]/_/g').state"

  # Check if source exists
  if [ ! -d "$src" ]; then
    log "ERROR: Source directory not found - $src"
    return 1
  fi

  # Check last sync time
  last_sync=0
  if [ -f "$state_file" ]; then
    last_sync=$(cat "$state_file" 2>/dev/null)
  fi

  # Parse frequency
  unit=$(echo "$frequency" | tr -d '0-9')
  value=$(echo "$frequency" | tr -d 'a-zA-Z')

  # Default to minutes if no unit specified
  if [ -z "$unit" ]; then
    unit="m"
  fi

  # Default value
  if [ -z "$value" ]; then
    value=1
  fi

  # Set interval in seconds
  case "$unit" in
  s) interval="$value" ;;
  m) interval=$((value * 60)) ;;
  h) interval=$((value * 3600)) ;;
  d) interval=$((value * 86400)) ;;
  w) interval=$((value * 604800)) ;;
  *)
    log "ERROR: Invalid frequency unit - $unit"
    return 1
    ;;
  esac

  now=$(date +%s)

  # Check if we should skip this sync
  if [ -n "$last_sync" ] && [ "$last_sync" -gt 0 ] 2>/dev/null; then
    time_diff=$((now - last_sync))
    if [ "$time_diff" -lt "$interval" ]; then
      # Skip silently as requested
      return 0
    fi
  fi

  # Start synchronization
  log "SYNC: $src -> $dest"

  # Initialize counters
  new_files=0
  updated_files=0
  same_files=0
  total_files=0

  # Process files
  find "$src" -type f 2>/dev/null | while read -r src_file; do
    rel_path="${src_file#$src}"
    # Remove leading slash if present
    rel_path="${rel_path#/}"
    dest_file="${dest}/${rel_path}"

    # Initialize counters
    total_files=$((total_files + 1))

    # Create destination directory structure if needed
    mkdir -p "$(dirname "$dest_file")" 2>/dev/null

    if [ ! -f "$dest_file" ]; then
      # New file
      cp -p "$src_file" "$dest_file" 2>/dev/null
      if [ $? -eq 0 ]; then
        log "  NEW: $rel_path"
        new_files=$((new_files + 1))
      else
        log "  FAILED: $rel_path"
      fi
    else
      # Compare files
      src_mtime=$(get_file_mtime "$src_file")
      dest_mtime=$(get_file_mtime "$dest_file")
      src_size=$(get_file_size "$src_file")
      dest_size=$(get_file_size "$dest_file")

      # Check if files are different
      if [ -z "$src_mtime" ] || [ -z "$dest_mtime" ]; then
        # If we can't get mtime, use size
        if [ "$src_size" -ne "$dest_size" ]; then
          should_update=1
        else
          should_update=0
        fi
      elif [ "$src_mtime" -gt "$dest_mtime" ] || [ "$src_size" -ne "$dest_size" ]; then
        should_update=1
      else
        should_update=0
      fi

      if [ "$should_update" -eq 1 ]; then
        # File changed
        cp -p "$src_file" "$dest_file" 2>/dev/null
        if [ $? -eq 0 ]; then
          log "  UPDATED: $rel_path"
          updated_files=$((updated_files + 1))
        else
          log "  FAILED: $rel_path"
        fi
      else
        # File unchanged
        same_files=$((same_files + 1))
      fi
    fi
  done

  # Update state file
  echo "$now" >"$state_file" 2>/dev/null

  # Log summary
  if [ "$total_files" -eq 0 ]; then
    log "NO CHANGE: $src -> $dest (0 files)"
  elif [ "$new_files" -eq 0 ] && [ "$updated_files" -eq 0 ]; then
    # Remove the SYNC and SUMMARY lines and replace with NO CHANGE
    # We'll handle this differently
    log "NO CHANGE: $src -> $dest ($total_files files)"
  else
    log "SUMMARY: total=$total_files, new=$new_files, updated=$updated_files, same=$same_files"
  fi
}

# Main execution
main() {
  # Write boundary marker
  start_time=$(date '+%Y-%m-%d %H:%M:%S')
  log "=== SYNC CHECK START at $start_time ==="

  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    log "ERROR: Configuration file not found - $CONFIG_FILE"
    exit 1
  fi

  # Track if any sync was actually performed
  sync_performed=0

  # Process each line in config file
  while IFS= read -r line; do
    # Remove comments and trim
    line=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Skip empty lines
    if [ -z "$line" ]; then
      continue
    fi

    # Parse source:destination:frequency
    src=$(echo "$line" | cut -d: -f1)
    dest=$(echo "$line" | cut -d: -f2)
    freq=$(echo "$line" | cut -d: -f3)

    # Validate
    if [ -z "$src" ] || [ -z "$dest" ] || [ -z "$freq" ]; then
      log "ERROR: Invalid configuration line: $line"
      continue
    fi

    # Run synchronization
    if sync_folder "$src" "$dest" "$freq"; then
      sync_performed=$((sync_performed + 1))
    fi

  done <"$CONFIG_FILE"

  end_time=$(date '+%Y-%m-%d %H:%M:%S')

  # If no sync was performed, remove the boundary markers
  if [ "$sync_performed" -eq 0 ]; then
    # Get line count
    line_count=$(wc -l <"$LOG_FILE" 2>/dev/null || echo 0)

    # Remove the last 2 lines (boundary markers)
    if [ "$line_count" -gt 2 ]; then
      # Save all lines except the boundary markers
      head -n -2 "$LOG_FILE" >"${LOG_FILE}.tmp" 2>/dev/null
      mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null
    fi
  else
    # Write end boundary
    log "=== SYNC CHECK END at $end_time ===\n"
  fi
}

# Run main
main
