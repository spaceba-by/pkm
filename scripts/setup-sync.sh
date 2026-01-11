#!/bin/bash

# PKM Sync Setup Script
# Configures rclone for bidirectional sync with S3

set -e

echo "======================================"
echo "PKM Sync Setup"
echo "======================================"
echo ""

# Check for rclone
if ! command -v rclone &> /dev/null; then
    echo "Error: rclone is not installed"
    echo ""
    echo "Install rclone:"
    echo "  macOS:   brew install rclone"
    echo "  Linux:   curl https://rclone.org/install.sh | sudo bash"
    echo "  Windows: Download from https://rclone.org/downloads/"
    exit 1
fi

echo "✓ rclone is installed"
echo ""

# Get configuration from terraform outputs if available
if [ -f "../outputs.json" ]; then
    S3_BUCKET_NAME=$(jq -r '.s3_bucket_name.value' ../outputs.json)
    AWS_REGION=$(jq -r '.rclone_remote_config.value' ../outputs.json | grep region | cut -d'=' -f2 | tr -d ' ')
    echo "Using values from Terraform outputs:"
    echo "  Bucket: $S3_BUCKET_NAME"
    echo "  Region: $AWS_REGION"
else
    echo "Enter your S3 bucket name:"
    read -r S3_BUCKET_NAME

    echo "Enter your AWS region (default: us-east-1):"
    read -r AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
fi

# Get local vault path
echo ""
echo "Enter the path to your local PKM vault:"
echo "(e.g., /Users/username/Documents/vault or ~/vault)"
read -r VAULT_PATH

# Expand tilde
VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

# Create vault directory if it doesn't exist
if [ ! -d "$VAULT_PATH" ]; then
    echo "Vault directory doesn't exist. Create it? (yes/no)"
    read -r CREATE_DIR
    if [ "$CREATE_DIR" = "yes" ]; then
        mkdir -p "$VAULT_PATH"
        echo "✓ Created vault directory: $VAULT_PATH"
    else
        echo "Error: Vault directory does not exist"
        exit 1
    fi
fi

echo ""
echo "======================================"
echo "Step 1: Configure rclone"
echo "======================================"

# Determine rclone config location
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    RCLONE_CONFIG_DIR="$HOME/.config/rclone"
    RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    RCLONE_CONFIG_DIR="$APPDATA/rclone"
    RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"
else
    RCLONE_CONFIG_DIR="$HOME/.config/rclone"
    RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"
fi

# Create rclone config directory
mkdir -p "$RCLONE_CONFIG_DIR"

# Create or append rclone config
if [ -f "$RCLONE_CONFIG_FILE" ]; then
    echo "rclone config already exists at $RCLONE_CONFIG_FILE"
    echo "Do you want to append the PKM remote? (yes/no)"
    read -r APPEND_CONFIG
    if [ "$APPEND_CONFIG" != "yes" ]; then
        echo "Skipping rclone config"
    else
        cat >> "$RCLONE_CONFIG_FILE" << EOF

[pkm-s3]
type = s3
provider = AWS
env_auth = true
region = $AWS_REGION
acl = private
EOF
        echo "✓ Appended pkm-s3 remote to rclone config"
    fi
else
    cat > "$RCLONE_CONFIG_FILE" << EOF
[pkm-s3]
type = s3
provider = AWS
env_auth = true
region = $AWS_REGION
acl = private
EOF
    echo "✓ Created rclone config at $RCLONE_CONFIG_FILE"
fi

echo ""
echo "======================================"
echo "Step 2: Test rclone connection"
echo "======================================"

if rclone lsd "pkm-s3:$S3_BUCKET_NAME" &> /dev/null; then
    echo "✓ Successfully connected to S3 bucket"
else
    echo "Error: Cannot connect to S3 bucket"
    echo "Please check:"
    echo "  1. AWS credentials are configured (run 'aws configure')"
    echo "  2. Bucket name is correct: $S3_BUCKET_NAME"
    echo "  3. You have permissions to access the bucket"
    exit 1
fi

echo ""
echo "======================================"
echo "Step 3: Initialize bisync"
echo "======================================"
echo "This will perform the first sync between local and S3."
echo "Continue? (yes/no)"
read -r INIT_SYNC

if [ "$INIT_SYNC" = "yes" ]; then
    echo "Running initial bisync..."
    rclone bisync "$VAULT_PATH" "pkm-s3:$S3_BUCKET_NAME" --resync --verbose
    echo "✓ Initial sync complete"
else
    echo "Skipped initial sync. You'll need to run this manually:"
    echo "  rclone bisync $VAULT_PATH pkm-s3:$S3_BUCKET_NAME --resync"
fi

echo ""
echo "======================================"
echo "Step 4: Set up automatic sync"
echo "======================================"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - launchd
    echo "Setting up launchd service for macOS..."

    PLIST_FILE="$HOME/Library/LaunchAgents/com.pkm.sync.plist"

    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pkm.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/rclone</string>
        <string>bisync</string>
        <string>$VAULT_PATH</string>
        <string>pkm-s3:$S3_BUCKET_NAME</string>
        <string>--conflict-resolve</string>
        <string>newer</string>
        <string>--conflict-loser</string>
        <string>rename</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.pkm-sync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.pkm-sync-error.log</string>
</dict>
</plist>
EOF

    echo "✓ Created launchd plist at $PLIST_FILE"

    # Load the service
    launchctl load "$PLIST_FILE" 2>/dev/null || true
    echo "✓ Loaded launchd service"

    echo ""
    echo "Sync service is now running!"
    echo "Logs: $HOME/.pkm-sync.log"
    echo ""
    echo "To stop:  launchctl stop com.pkm.sync"
    echo "To start: launchctl start com.pkm.sync"

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux - systemd
    echo "Setting up systemd service for Linux..."

    SYSTEMD_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_DIR"

    cat > "$SYSTEMD_DIR/pkm-sync.service" << EOF
[Unit]
Description=PKM Vault Sync
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rclone bisync $VAULT_PATH pkm-s3:$S3_BUCKET_NAME --conflict-resolve newer --conflict-loser rename

[Install]
WantedBy=default.target
EOF

    cat > "$SYSTEMD_DIR/pkm-sync.timer" << EOF
[Unit]
Description=PKM Vault Sync Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable pkm-sync.timer
    systemctl --user start pkm-sync.timer

    echo "✓ Created and started systemd service"
    echo ""
    echo "Check status: systemctl --user status pkm-sync.timer"
    echo "View logs: journalctl --user -u pkm-sync.service -f"

else
    echo "Automatic sync setup not available for this OS."
    echo "Manual sync command:"
    echo "  rclone bisync $VAULT_PATH pkm-s3:$S3_BUCKET_NAME --conflict-resolve newer --conflict-loser rename"
fi

echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Configuration:"
echo "  Local vault: $VAULT_PATH"
echo "  S3 bucket:   $S3_BUCKET_NAME"
echo "  AWS region:  $AWS_REGION"
echo ""
echo "Your vault is now syncing every 5 minutes."
echo ""
