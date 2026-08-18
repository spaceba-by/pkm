#!/bin/bash
#
# PKM vault sync: two-phase.
#
#   1. bisync  — bidirectional for human-authored notes, with _agent/ filtered out
#   2. copy    — one-way pull of _agent/, making S3 unconditionally authoritative
#
# Splitting the two means agent output can never be clobbered by a local edit,
# never produces a bisync conflict, and never participates in bisync's listing
# comparison. The pull is also cheaper than bisync: no listing snapshots, no
# lock, no check-sync, and --use-server-modtime avoids a HEAD per object.
#
# Configure via environment variables or edit the defaults below.

set -euo pipefail

VAULT_PATH="${PKM_VAULT_PATH:-$HOME/vault}"
BUCKET_NAME="${PKM_BUCKET_NAME:-}"
FILTER_FILE="${PKM_FILTER_FILE:-$HOME/.config/rclone/pkm-bisync-filter.txt}"
REMOTE="${PKM_RCLONE_REMOTE:-pkm-s3}"

if [ -z "$BUCKET_NAME" ]; then
    echo "Error: PKM_BUCKET_NAME is not set" >&2
    exit 1
fi

if [ ! -d "$VAULT_PATH" ]; then
    echo "Error: vault path does not exist: $VAULT_PATH" >&2
    exit 1
fi

if [ ! -f "$FILTER_FILE" ]; then
    echo "Error: filter file not found: $FILTER_FILE" >&2
    echo "Copy sync/pkm-bisync-filter.txt there, or set PKM_FILTER_FILE." >&2
    exit 1
fi

# Resolve rclone. Apple Silicon Homebrew installs to /opt/homebrew/bin, so a
# hardcoded /usr/local/bin/rclone does not work on modern Macs.
resolve_rclone() {
    if [ -n "${PKM_RCLONE_PATH:-}" ]; then
        echo "$PKM_RCLONE_PATH"
        return
    fi
    for candidate in /opt/homebrew/bin/rclone /usr/local/bin/rclone; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return
        fi
    done
    command -v rclone || true
}

RCLONE="$(resolve_rclone)"
if [ -z "$RCLONE" ] || [ ! -x "$RCLONE" ]; then
    echo "Error: rclone not found. Install with: brew install rclone" >&2
    exit 1
fi

status=0

echo "==> Phase 1: bisync notes (excluding _agent/)"
if ! "$RCLONE" bisync "$VAULT_PATH" "$REMOTE:$BUCKET_NAME" \
    --filters-file "$FILTER_FILE" \
    --conflict-resolve newer \
    --conflict-loser rename \
    --recover \
    --resilient \
    --max-lock 2m \
    --verbose; then
    status=$?
    echo "bisync failed with exit code $status" >&2
fi

# The _agent/ pull is independent of bisync, so run it even when bisync failed.
# vector-index.json is a monolithic embeddings blob rewritten in full on every
# index run, and dispatch/ holds unbounded ECS job artifacts (including code
# trees) -- neither belongs in an Obsidian vault.
echo "==> Phase 2: pull _agent/ from S3 (remote authoritative)"
if ! "$RCLONE" copy "$REMOTE:$BUCKET_NAME/_agent" "$VAULT_PATH/_agent" \
    --use-server-modtime \
    --exclude "search/vector-index.json" \
    --exclude "dispatch/**" \
    --verbose; then
    pull_status=$?
    echo "_agent pull failed with exit code $pull_status" >&2
    [ "$status" -eq 0 ] && status=$pull_status
fi

exit "$status"
