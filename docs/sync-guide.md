# Vault Synchronization Guide

This guide covers setting up and troubleshooting vault synchronization between your local devices and S3.

For detailed setup instructions, see [`sync/README.md`](../sync/README.md).

## Quick Start

```bash
# Run the setup script
cd scripts
./setup-sync.sh
```

## How Sync Works

The PKM Agent System uses **rclone bisync** for bidirectional synchronization:

```
Local Vault ←→ rclone bisync ←→ S3 Bucket
     │                              │
     │                              ▼
     │                        EventBridge
     │                              │
     │                              ▼
     │                        Lambda Processing
     │                              │
     │                              ▼
     └────────────────────── _agent/ outputs
```

### Sync Frequency
- **macOS/Linux:** Every 5 minutes (automatic)
- **iOS:** Hourly or on-demand (using Obsidian plugin)
- **Manual:** On-demand via command line

### Conflict Resolution
- **Strategy:** Newer file wins
- **Conflict handling:** Older file renamed to `filename.conflict`
- **Location:** Conflicts appear in both local and S3

## Platform-Specific Setup

### macOS

Uses **launchd** for automatic sync:

```bash
# Setup (run setup-sync.sh or manually):
cp sync/com.pkm.sync.plist.template ~/Library/LaunchAgents/com.pkm.sync.plist

# Edit file to replace USERNAME and BUCKET_NAME
nano ~/Library/LaunchAgents/com.pkm.sync.plist

# Load and start
launchctl load ~/Library/LaunchAgents/com.pkm.sync.plist
launchctl start com.pkm.sync

# Check status
launchctl list | grep pkm.sync

# View logs
tail -f ~/.pkm-sync.log
tail -f ~/.pkm-sync-error.log

# Stop sync
launchctl stop com.pkm.sync
launchctl unload ~/Library/LaunchAgents/com.pkm.sync.plist
```

### Linux

Uses **systemd** timers:

```bash
# Create service files
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/pkm-sync.service
nano ~/.config/systemd/user/pkm-sync.timer

# Enable and start
systemctl --user daemon-reload
systemctl --user enable pkm-sync.timer
systemctl --user start pkm-sync.timer

# Check status
systemctl --user status pkm-sync.timer
systemctl --user status pkm-sync.service

# View logs
journalctl --user -u pkm-sync.service -f

# Stop sync
systemctl --user stop pkm-sync.timer
systemctl --user disable pkm-sync.timer
```

### iOS

#### Option 1: Obsidian + Remotely Save Plugin (Recommended)

1. Install Obsidian for iOS
2. Open your vault in Obsidian
3. Install "Remotely Save" community plugin
4. Configure plugin settings:
   - Remote: Amazon S3
   - S3 Endpoint: `s3.amazonaws.com`
   - Region: Your AWS region (e.g., `us-east-1`)
   - Bucket: Your bucket name
   - Access Key ID: From AWS IAM
   - Secret Access Key: From AWS IAM
   - Prefix: (leave empty)
5. Enable auto-sync:
   - Sync on open: ✓
   - Sync interval: 60 minutes
   - Sync on file change: ✓

**Creating IAM Credentials for iOS:**
```bash
aws iam create-access-key --user-name your-username
```

Save the Access Key ID and Secret Access Key securely.

#### Option 2: a-Shell + rclone (Advanced)

For users comfortable with command-line tools on iOS.

See [sync/README.md](../sync/README.md) for detailed instructions.

### Windows

Uses **Task Scheduler**:

1. Create batch file `pkm-sync.bat`:
   ```batch
   @echo off
   rclone bisync C:\path\to\vault pkm-s3:BUCKET_NAME --conflict-resolve newer --conflict-loser rename
   ```

2. Create scheduled task:
   - Open Task Scheduler
   - Create Basic Task → "PKM Sync"
   - Trigger: Daily, repeat every 5 minutes
   - Action: Start program → Select `pkm-sync.bat`

## Manual Sync Commands

### Initial Setup (First Time)

```bash
# Initialize bisync (required before first sync)
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --resync
```

### Regular Sync

```bash
# Bidirectional sync
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME \
  --conflict-resolve newer \
  --conflict-loser rename \
  --verbose
```

### One-Way Sync

```bash
# Local → S3 only
rclone sync /path/to/vault pkm-s3:BUCKET_NAME --verbose

# S3 → Local only (be careful!)
rclone sync pkm-s3:BUCKET_NAME /path/to/vault --verbose
```

### Dry Run (Test)

```bash
# See what would change without making changes
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --dry-run --verbose
```

## Troubleshooting

### Error: "bisync is in a bad state"

**Cause:** Previous sync interrupted or conflicts not resolved

**Solution:**
```bash
# Resync (this will resolve conflicts by using newer files)
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --resync
```

### Error: "Access Denied" when syncing

**Cause:** AWS credentials not configured or insufficient permissions

**Solution:**
```bash
# Verify AWS credentials
aws configure list
aws sts get-caller-identity

# Test S3 access
aws s3 ls s3://BUCKET_NAME
```

### Error: "No transfer found"

**Cause:** rclone not found in PATH

**Solution:**
```bash
# Verify rclone installation
which rclone
rclone version

# If not found, install:
# macOS: brew install rclone
# Linux: curl https://rclone.org/install.sh | sudo bash
```

### Sync Running Too Slowly

**Cause:** Large number of files or slow network

**Solutions:**
1. Use `--fast-list` flag (caches directory listings)
2. Exclude unnecessary files:
   ```bash
   rclone bisync /path/to/vault pkm-s3:BUCKET_NAME \
     --exclude ".obsidian/**" \
     --exclude "*.tmp"
   ```
3. Reduce sync frequency (edit launchd/systemd interval)

### Conflicts Keep Appearing

**Cause:** Multiple devices modifying same file simultaneously

**Solutions:**
1. Reduce sync frequency on one device
2. Use different files/directories per device
3. Manually resolve conflicts:
   ```bash
   # Find conflicts
   find /path/to/vault -name "*.conflict*"

   # Review and delete or rename as needed
   ```

### iOS Sync Not Working

**Obsidian + Remotely Save:**
1. Check AWS credentials in plugin settings
2. Verify bucket name and region
3. Test connection in plugin settings
4. Check Obsidian logs: Settings → Remotely Save → Debug

**Network Issues:**
- Ensure cellular data allowed for Obsidian
- Check if VPN interfering
- Verify S3 bucket accessibility

### Agent Outputs Not Syncing Back

**Cause:** `_agent/` directory excluded or permission issues

**Check:**
```bash
# Ensure _agent directory exists locally
ls /path/to/vault/_agent

# Verify S3 contents
aws s3 ls s3://BUCKET_NAME/_agent/ --recursive

# Force sync
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --resync
```

## Monitoring Sync

### Check Last Sync Time

```bash
# macOS (launchd)
stat ~/.pkm-sync.log

# Linux (systemd)
systemctl --user status pkm-sync.timer

# Check S3 bucket last modified
aws s3api head-object --bucket BUCKET_NAME --key path/to/file.md
```

### View Sync Logs

```bash
# macOS
tail -f ~/.pkm-sync.log

# Linux
journalctl --user -u pkm-sync.service -f

# rclone verbose output
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME --verbose --dry-run
```

### Sync Statistics

```bash
# Count files in vault
find /path/to/vault -name "*.md" | wc -l

# Count files in S3
aws s3 ls s3://BUCKET_NAME --recursive | grep "\.md$" | wc -l

# Compare sizes
du -sh /path/to/vault
aws s3 ls s3://BUCKET_NAME --recursive --human-readable --summarize
```

## Best Practices

1. **Regular Backups:** S3 versioning is enabled, but backup locally too
2. **Test Conflicts:** Intentionally create conflicts to understand behavior
3. **Monitor Logs:** Check logs weekly for errors
4. **Exclude Unnecessary Files:** Don't sync temporary files
5. **Use Tags:** Tag files to track which device created them
6. **Limit Concurrent Edits:** Avoid editing same file on multiple devices
7. **Resolve Conflicts Promptly:** Don't let conflicts accumulate

## Advanced Configuration

### Custom Filters

Exclude specific directories:
```bash
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME \
  --exclude ".obsidian/**" \
  --exclude ".trash/**" \
  --exclude "*.tmp"
```

### Bandwidth Limiting

Useful on metered connections:
```bash
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME \
  --bwlimit 1M  # Limit to 1 MB/s
```

### Compression

Enable compression for faster transfers:
```bash
rclone bisync /path/to/vault pkm-s3:BUCKET_NAME \
  --s3-upload-cutoff 0 \
  --s3-chunk-size 5M
```

## Security Considerations

1. **AWS Credentials:** Never commit credentials to git
2. **IAM Permissions:** Use minimal permissions (S3 read/write only)
3. **MFA:** Enable MFA on AWS account
4. **Encryption:** S3 server-side encryption enabled by default
5. **rclone Config:** Protect rclone config file (chmod 600)

## FAQ

**Q: Can I sync multiple vaults?**
A: Yes, create separate rclone remotes and S3 buckets for each vault.

**Q: What if I delete a file locally?**
A: It will be deleted from S3 on next sync (and vice versa).

**Q: Can I sync to multiple S3 buckets?**
A: Yes, run separate bisync commands for each bucket.

**Q: Is there a web interface?**
A: No, but you can access files via AWS Console S3 browser.

**Q: Can I share my vault with others?**
A: Yes, grant them IAM access to the S3 bucket. Each user needs their own sync setup.

## References

- [rclone Documentation](https://rclone.org/docs/)
- [rclone bisync Guide](https://rclone.org/bisync/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Obsidian Remotely Save Plugin](https://github.com/remotely-save/remotely-save)
