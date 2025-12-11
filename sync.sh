#!/bin/sh
# sync.sh - Minimal folder synchronization script

# Initialize paths
SCRIPT_DIR=$(dirname "$0")
CONFIG_FILE="${SCRIPT_DIR}/sync.conf"
STATE_DIR="${SCRIPT_DIR}/.sync_state"
LOG_FILE="${SCRIPT_DIR}/sync.log"
DATA_DIR="${SCRIPT_DIR}/data"

# Parse command line arguments
FORCE_SYNC=0
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
  FORCE_SYNC=1
fi

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
  ls -l "$file" 2>/dev/null | awk '{print $6, $7, $8}' | date -jf "%b %d %H:%M" +%s 2>/dev/null || echo "0"
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

# Get link target
get_link_target() {
  file="$1"
  # Try readlink
  if readlink "$file" 2>/dev/null; then
    return
  fi
  # Try ls as fallback
  ls -l "$file" 2>/dev/null | awk -F' -> ' '{print $2}' || echo ""
}

# Safe find function that returns regular files and symlinks
find_files_and_links() {
  dir="$1"
  # Find regular files (-type f) and symbolic links (-type l)
  find "$dir" \( -type f -o -type l \) 2>/dev/null | while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    # Verify it's a file or symlink
    if [ -f "$line" ] || [ -L "$line" ]; then
      echo "$line"
    fi
  done
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

# Copy symlink preserving target
copy_symlink() {
  src="$1"
  dest="$2"

  # Get link target
  target=$(get_link_target "$src")

  if [ -z "$target" ]; then
    return 1
  fi

  # Remove existing file/link
  rm -f "$dest" 2>/dev/null

  # Create symlink
  ln -sf "$target" "$dest" 2>/dev/null
  return $?
}

# Check if symlink needs update
symlink_needs_update() {
  src="$1"
  dest="$2"

  # If destination doesn't exist, needs update
  if [ ! -L "$dest" ]; then
    return 0
  fi

  # Get both link targets
  src_target=$(get_link_target "$src")
  dest_target=$(get_link_target "$dest")

  # Compare targets
  if [ "$src_target" != "$dest_target" ]; then
    return 0
  fi

  # Compare modification times
  src_mtime=$(get_file_mtime "$src")
  dest_mtime=$(get_file_mtime "$dest")

  if [ "$src_mtime" -gt "$dest_mtime" ] 2>/dev/null; then
    return 0
  fi

  return 1
}

# Check if sync should be performed
should_sync() {
  state_file="$1"
  frequency="$2"
  now="$3"
  last_sync="$4"

  # If force mode, always sync
  if [ "$FORCE_SYNC" -eq 1 ]; then
    return 0
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
  *) return 0 ;; # Invalid unit, sync anyway
  esac

  # Check if we should sync
  if [ -n "$last_sync" ] && [ "$last_sync" -gt 0 ] 2>/dev/null; then
    time_diff=$((now - last_sync))
    if [ "$time_diff" -ge "$interval" ]; then
      return 0
    else
      return 1
    fi
  fi

  # No previous sync, should sync
  return 0
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
  safe_src=$(echo "$src" | sed 's/[^a-zA-Z0-9]/_/g')
  safe_dest=$(echo "$dest" | sed 's/[^a-zA-Z0-9]/_/g')
  state_file="${STATE_DIR}/${safe_src}_to_${safe_dest}.state"

  # Check if source exists
  if [ ! -d "$src" ] && [ ! -L "$src" ]; then
    log "ERROR: Source not found - $src"
    return 1
  fi

  # Check last sync time
  last_sync=0
  if [ -f "$state_file" ]; then
    last_sync=$(cat "$state_file" 2>/dev/null)
  fi

  now=$(date +%s)

  # Check if we should perform sync
  if ! should_sync "$state_file" "$frequency" "$now" "$last_sync"; then
    # Log skipped sync for debugging
    if [ "$FORCE_SYNC" -eq 0 ]; then
      time_diff=$((now - last_sync))
      unit=$(echo "$frequency" | tr -d '0-9')
      value=$(echo "$frequency" | tr -d 'a-zA-Z')
      [ -z "$value" ] && value=1
      [ -z "$unit" ] && unit="m"

      case "$unit" in
      s) interval="$value" ;;
      m) interval=$((value * 60)) ;;
      h) interval=$((value * 3600)) ;;
      d) interval=$((value * 86400)) ;;
      w) interval=$((value * 604800)) ;;
      *) interval=60 ;;
      esac

      remaining=$((interval - time_diff))
      if [ "$remaining" -gt 0 ]; then
        # Silent skip as requested
        return 0
      fi
    fi
  fi

  # Start synchronization
  log "SYNC: $src -> $dest"

  # Initialize counters
  new_files=0
  new_links=0
  updated_files=0
  updated_links=0
  same_files=0
  same_links=0
  total_items=0

  # Store log entries temporarily
  temp_log=$(mktemp 2>/dev/null || echo "/tmp/sync_temp_$$.log")

  # Process files and symlinks
  find_files_and_links "$src" | while read -r src_item; do
    # Skip empty lines
    [ -z "$src_item" ] && continue

    rel_path="${src_item#$src}"
    # Remove leading slash if present
    rel_path="${rel_path#/}"
    dest_item="${dest}/${rel_path}"

    # Initialize counters
    total_items=$((total_items + 1))

    # Create destination directory structure if needed
    mkdir -p "$(dirname "$dest_item")" 2>/dev/null

    # Check if it's a symlink
    if [ -L "$src_item" ]; then
      # Handle symbolic link
      if [ ! -L "$dest_item" ]; then
        # New symlink
        if copy_symlink "$src_item" "$dest_item"; then
          echo "  NEW LINK: $rel_path -> $(get_link_target "$src_item")" >>"$temp_log"
          new_links=$((new_links + 1))
        else
          echo "  FAILED LINK: $rel_path" >>"$temp_log"
        fi
      else
        # Existing symlink, check if update needed
        if symlink_needs_update "$src_item" "$dest_item"; then
          if copy_symlink "$src_item" "$dest_item"; then
            echo "  UPDATED LINK: $rel_path -> $(get_link_target "$src_item")" >>"$temp_log"
            updated_links=$((updated_links + 1))
          else
            echo "  FAILED LINK: $rel_path" >>"$temp_log"
          fi
        else
          # Link unchanged
          same_links=$((same_links + 1))
        fi
      fi
    else
      # Handle regular file
      if [ ! -f "$dest_item" ]; then
        # New file
        if cp -p "$src_item" "$dest_item" 2>/dev/null; then
          echo "  NEW: $rel_path" >>"$temp_log"
          new_files=$((new_files + 1))
        else
          echo "  FAILED: $rel_path" >>"$temp_log"
        fi
      else
        # Compare files
        src_mtime=$(get_file_mtime "$src_item")
        dest_mtime=$(get_file_mtime "$dest_item")
        src_size=$(get_file_size "$src_item")
        dest_size=$(get_file_size "$dest_item")

        # Check if files are different
        should_update=0
        if [ -z "$src_mtime" ] || [ -z "$dest_mtime" ]; then
          # If we can't get mtime, use size
          if [ "$src_size" -ne "$dest_size" ] 2>/dev/null; then
            should_update=1
          fi
        elif [ "$src_mtime" -gt "$dest_mtime" ] 2>/dev/null || { [ "$src_size" != "$dest_size" ] 2>/dev/null; }; then
          should_update=1
        fi

        if [ "$should_update" -eq 1 ]; then
          # File changed
          if cp -p "$src_item" "$dest_item" 2>/dev/null; then
            echo "  UPDATED: $rel_path" >>"$temp_log"
            updated_files=$((updated_files + 1))
          else
            echo "  FAILED: $rel_path" >>"$temp_log"
          fi
        else
          # File unchanged
          same_files=$((same_files + 1))
        fi
      fi
    fi
  done

  # Update state file
  echo "$now" >"$state_file" 2>/dev/null

  # Calculate totals
  total_new=$((new_files + new_links))
  total_updated=$((updated_files + updated_links))
  total_same=$((same_files + same_links))

  # Write detailed log if there were changes
  if [ -f "$temp_log" ]; then
    if [ "$total_new" -gt 0 ] || [ "$total_updated" -gt 0 ]; then
      cat "$temp_log" >>"$LOG_FILE"
      log "SUMMARY: total=$total_items, new=$total_new (files:$new_files,links:$new_links), updated=$total_updated (files:$updated_files,links:$updated_links), same=$total_same"
    fi
    rm -f "$temp_log"
  fi

  # Log single line if no changes
  if [ "$total_items" -gt 0 ] && [ "$total_new" -eq 0 ] && [ "$total_updated" -eq 0 ]; then
    # Remove the SYNC line
    sed -i '' '$d' "$LOG_FILE" 2>/dev/null
    # Write NO CHANGE line
    log "NO CHANGE: $src -> $dest ($total_items items)"
  fi
}

# Main execution
main() {
  # Write boundary marker
  start_time=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$start_time] === SYNC CHECK START ===" >>"$LOG_FILE"

  # Check if config file exists
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "[$start_time] ERROR: Configuration file not found - $CONFIG_FILE" >>"$LOG_FILE"
    exit 1
  fi

  # Track if any sync was actually performed
  sync_performed=0
  skipped_count=0
  line_number=0

  # Process each line in config file
  while IFS= read -r line; do
    line_number=$((line_number + 1))

    # Remove comments and trim
    clean_line=$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

    # Skip empty lines
    if [ -z "$clean_line" ]; then
      continue
    fi

    # Parse source:destination:frequency
    src=$(echo "$clean_line" | cut -d: -f1)
    dest=$(echo "$clean_line" | cut -d: -f2)
    freq=$(echo "$clean_line" | cut -d: -f3)

    # Validate
    if [ -z "$src" ] || [ -z "$dest" ] || [ -z "$freq" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Invalid configuration at line $line_number: $line" >>"$LOG_FILE"
      continue
    fi

    # Get state file info for checking
    dest_resolved=$(resolve_destination "$dest")
    safe_src=$(echo "$src" | sed 's/[^a-zA-Z0-9]/_/g')
    safe_dest=$(echo "$dest_resolved" | sed 's/[^a-zA-Z0-9]/_/g')
    state_file="${STATE_DIR}/${safe_src}_to_${safe_dest}.state"

    # Check if source exists
    if [ ! -d "$src" ] && [ ! -L "$src" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Source not found - $src" >>"$LOG_FILE"
      continue
    fi

    # Check last sync time
    last_sync=0
    if [ -f "$state_file" ]; then
      last_sync=$(cat "$state_file" 2>/dev/null)
    fi

    now=$(date +%s)

    # Check if we should perform sync
    if ! should_sync "$state_file" "$freq" "$now" "$last_sync"; then
      skipped_count=$((skipped_count + 1))
      continue
    fi

    # Run synchronization
    if sync_folder "$src" "$dest" "$freq"; then
      sync_performed=$((sync_performed + 1))
    fi

  done <"$CONFIG_FILE"

  end_time=$(date '+%Y-%m-%d %H:%M:%S')

  # Log sync summary
  if [ "$FORCE_SYNC" -eq 1 ]; then
    echo "[$end_time] Force sync completed: $sync_performed tasks executed" >>"$LOG_FILE"
  elif [ "$sync_performed" -eq 0 ] && [ "$skipped_count" -gt 0 ]; then
    # Remove boundary markers if all tasks were skipped
    sed -i '' '$d' "$LOG_FILE" 2>/dev/null
    return
  fi

  # Only write end boundary if we wrote start boundary
  if [ "$sync_performed" -gt 0 ] || grep -q "SYNC CHECK START" "$LOG_FILE"; then
    echo "[$end_time] === SYNC CHECK END ===" >>"$LOG_FILE"
    echo "" >>"$LOG_FILE"
  fi
}

# Show usage
show_usage() {
  echo "Usage: $0 [OPTION]"
  echo "Minimal folder synchronization script"
  echo ""
  echo "Options:"
  echo "  -f, --force    Force sync all tasks regardless of frequency"
  echo "  -h, --help     Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0             # Normal sync (respect frequency settings)"
  echo "  $0 --force     # Force sync all tasks"
  exit 0
}

# Parse help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  show_usage
fi

# Run main
main
