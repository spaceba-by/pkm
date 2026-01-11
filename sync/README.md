# PKM Vault Sync Configuration

This directory contains configuration templates for syncing your local PKM vault with S3 using rclone.

## Prerequisites

1. Install rclone:
   ```bash
   # macOS
   brew install rclone

   # Linux
   curl https://rclone.org/install.sh | sudo bash

   # Windows
   # Download from https://rclone.org/downloads/
   ```

2. Configure AWS credentials:
   ```bash
   aws configure
   ```

## Setup Instructions

### 1. Configure rclone

Copy the template and customize:

```bash
# Linux/macOS
mkdir -p ~/.config/rclone
cp rclone.conf.template ~/.config/rclone/rclone.conf

# Edit the config to set your AWS region
nano ~/.config/rclone/rclone.conf
```

### 2. Test rclone connection

```bash
rclone lsd pkm-s3:YOUR-BUCKET-NAME
```

### 3. Initialize bisync (FIRST TIME ONLY)

```bash
# Replace paths with your actual values
rclone bisync /path/to/local/vault pkm-s3:YOUR-BUCKET-NAME --resync
```

### 4. Set up automatic sync

#### macOS (using launchd)

```bash
# 1. Copy template
cp com.pkm.sync.plist.template ~/Library/LaunchAgents/com.pkm.sync.plist

# 2. Edit the file - replace USERNAME and BUCKET_NAME
nano ~/Library/LaunchAgents/com.pkm.sync.plist

# 3. Load the service
launchctl load ~/Library/LaunchAgents/com.pkm.sync.plist

# 4. Start the service
launchctl start com.pkm.sync

# 5. Check status
launchctl list | grep pkm.sync
```

#### Linux (using systemd)

Create `~/.config/systemd/user/pkm-sync.service`:

```ini
[Unit]
Description=PKM Vault Sync
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rclone bisync /path/to/local/vault pkm-s3:BUCKET_NAME --conflict-resolve newer --conflict-loser rename

[Install]
WantedBy=default.target
```

Create `~/.config/systemd/user/pkm-sync.timer`:

```ini
[Unit]
Description=PKM Vault Sync Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl --user enable pkm-sync.timer
systemctl --user start pkm-sync.timer
systemctl --user status pkm-sync.timer
```

#### Windows (using Task Scheduler)

Create a batch script `pkm-sync.bat`:

```batch
@echo off
rclone bisync C:\path\to\vault pkm-s3:BUCKET_NAME --conflict-resolve newer --conflict-loser rename
```

Then create a scheduled task:
1. Open Task Scheduler
2. Create Basic Task → Name it "PKM Sync"
3. Trigger: Daily, repeat every 5 minutes
4. Action: Start a program → Select your pkm-sync.bat

### 5. Manual sync command

For manual syncing:

```bash
rclone bisync /path/to/local/vault pkm-s3:YOUR-BUCKET-NAME \
  --conflict-resolve newer \
  --conflict-loser rename \
  --verbose
```

## Conflict Resolution

The sync is configured with:
- `--conflict-resolve newer`: Newer file wins in conflicts
- `--conflict-loser rename`: Older file is renamed with `.conflict` suffix

## iOS Sync

### Option 1: Obsidian + Remotely Save Plugin

1. Install Obsidian mobile app
2. Install "Remotely Save" plugin
3. Configure S3 settings in plugin:
   - S3 Endpoint: `s3.amazonaws.com`
   - Region: Your AWS region
   - Bucket: Your bucket name
   - Access Key ID & Secret: From AWS IAM
4. Enable auto-sync in plugin settings

### Option 2: a-Shell + rclone (Advanced)

1. Install a-Shell from App Store
2. Install rclone in a-Shell:
   ```bash
   pkg install rclone
   ```
3. Configure rclone (same as desktop)
4. Create Shortcuts automation to run sync command

## Monitoring

### Check sync logs (macOS)

```bash
tail -f ~/.pkm-sync.log
tail -f ~/.pkm-sync-error.log
```

### Check sync logs (Linux systemd)

```bash
journalctl --user -u pkm-sync.service -f
```

## Troubleshooting

### "RCLONE_ENCRYPT_V0" error

Initialize bisync:
```bash
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --resync
```

### Permission denied

Ensure AWS credentials are valid:
```bash
aws s3 ls s3://YOUR-BUCKET-NAME
```

### Conflicts not resolving

Check that `--conflict-resolve newer` is in your command.

### Sync not running automatically

**macOS:**
```bash
launchctl list | grep pkm
cat ~/.pkm-sync-error.log
```

**Linux:**
```bash
systemctl --user status pkm-sync.timer
systemctl --user status pkm-sync.service
```

## Security Notes

- Never commit AWS credentials to git
- Use IAM user with minimal permissions (S3 access only)
- Enable MFA on AWS account
- Consider using AWS SSO for credential management
- Keep rclone config file secure (600 permissions)

## Uninstalling

### macOS

```bash
launchctl stop com.pkm.sync
launchctl unload ~/Library/LaunchAgents/com.pkm.sync.plist
rm ~/Library/LaunchAgents/com.pkm.sync.plist
```

### Linux

```bash
systemctl --user stop pkm-sync.timer
systemctl --user disable pkm-sync.timer
rm ~/.config/systemd/user/pkm-sync.*
```
