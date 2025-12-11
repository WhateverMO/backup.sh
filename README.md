[中文](README-zh.md) | English

Folder Sync Backup System

A minimal, zero-dependency folder synchronization system with incremental backup only.

Key Principle

This is a one-way backup system:  
• ✅ Copies new files from source to destination  

• ✅ Updates changed files from source to destination  

• ❌ Does NOT delete files from destination (if deleted from source)  

• ❌ Does NOT sync deletions in any direction

When to Use Each Script

1. sync.sh - One-time Synchronization

Use when: You want to run backup manually, once.
./sync.sh

• Runs all sync tasks defined in sync.conf

• Respects frequency settings

• Outputs to sync.log

2. daemon.sh - Continuous Background Sync

Use when: You want automatic backups while logged in.
./daemon.sh           # Foreground
nohup ./daemon.sh &   # Background

• Runs sync.sh every 60 seconds

• Keeps running until stopped

• Good for development/testing

3. install-cron.sh - Permanent Scheduled Sync

Use when: You want reliable, scheduled backups (recommended).
./install-cron.sh

• Adds cron job to run every minute

• Runs even when logged out

• Most reliable for production

4. uninstall-cron.sh - Remove Scheduled Sync

Use when: You want to stop automatic backups.
./uninstall-cron.sh

• Removes the cron job

• Does not delete backed up files

Quick Start

1. Create config (sync.conf):

   /path/to/source:/path/to/destination:1h

2. Test once:
   ./sync.sh
   tail -f sync.log

3. Setup automatic (choose one):
   ./daemon.sh &       # For temporary use
   ./install-cron.sh   # For permanent use

Important Notes

• Incremental only: Never deletes files from backup

• Check logs: sync.log shows what happened

• State stored: .sync_state/ tracks last sync time

• Backups stored: data/ (for relative paths) or your configured paths
