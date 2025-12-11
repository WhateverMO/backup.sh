[中文](README-zh.md) | English

# Folder Sync Backup System

A minimal, zero-dependency folder synchronization system with **incremental backup only**.

## Key Principle

**This is a one-way backup system**:  

- ✅ **Copies** new files from source to destination  
- ✅ **Updates** changed files from source to destination  
- ❌ **Does NOT delete** files from destination (if deleted from source)  
- ❌ **Does NOT sync deletions** in any direction

## How to Write Configuration

### Configuration Format (`sync.conf`)

```
source_path:destination_path:frequency
```

### Examples

**Example 1: Absolute destination path**

```
/home/user/documents:/backup/documents:1h
```

**Example 2: Relative destination path** (goes to `data/` folder)

```
/home/user/photos:my-photos:1d
# Destination becomes: /path/to/project/data/my-photos/
```

**Example 3: Multiple sync tasks**

```
/home/user/work:work-backup:30m
/home/user/music:music-backup:1d
/etc:system-config:1w
```

### Frequency Units

- `s` - seconds (e.g., `30s`)
- `m` - minutes (e.g., `5m`, `30m`)
- `h` - hours (e.g., `1h`, `6h`)
- `d` - days (e.g., `1d`, `7d`)
- `w` - weeks (e.g., `1w`, `2w`)

## When to Use Each Script

### 1. `sync.sh` - One-time Synchronization

**Use when:** You want to run backup manually, once.

```bash
./sync.sh
```

- Runs all sync tasks defined in `sync.conf`
- Respects frequency settings
- Outputs to `sync.log`

### 2. `daemon.sh` - Continuous Background Sync

**Use when:** You want automatic backups while logged in.

```bash
./daemon.sh           # Foreground
./daemon.sh &         # Background
fg                    # back to foreground
```

- Runs `sync.sh` every 60 seconds
- Keeps running until stopped
- Good for development/testing

### 3. `install-cron.sh` - Permanent Scheduled Sync

**Use when:** You want reliable, scheduled backups (recommended).

```bash
./install-cron.sh
```

- Adds cron job to run every minute
- Runs even when logged out
- Most reliable for production

### 4. `uninstall-cron.sh` - Remove Scheduled Sync

**Use when:** You want to stop automatic backups.

```bash
./uninstall-cron.sh
```

- Removes the cron job
- Does not delete backed up files
