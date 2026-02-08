#!/bin/bash
# OpenClaw Auto-Update Script
# Runs daily at 5am EST, checks for and installs updates

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-update.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of openclaw-update.sh is already running. Exiting."
    exit 0
fi

# Structured logging
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

# Directory setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="/home/mccargo/.openclaw/workspace"
LOG_DIR="$WORKSPACE/logs"
UPDATE_LOG="$LOG_DIR/update-$(date +%Y%m%d).log"
UPDATE_STATUS="$WORKSPACE/.update-status.json"
CHANGES_FILE="$WORKSPACE/.update-changes.txt"

# Create logs directory if needed
mkdir -p "$LOG_DIR"

# Initialize status file
echo '{"updated": false, "timestamp": null, "version_before": "", "version_after": "", "changes": []}' > "$UPDATE_STATUS"

# Get current version before update
# Parse the table output - version is on the "Update" line with "npm latest"
VERSION_BEFORE=$(openclaw update status 2>/dev/null | grep "npm latest" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

echo "=== OpenClaw Update Check - $(date) ===" | tee -a "$UPDATE_LOG"
echo "Current version: $VERSION_BEFORE" | tee -a "$UPDATE_LOG"

# Run update (non-interactive, with JSON output for parsing)
echo "Checking for updates..." | tee -a "$UPDATE_LOG"
UPDATE_OUTPUT=$(timeout 600 openclaw update --yes --json 2>&1)
UPDATE_EXIT=$?

# Log the output
echo "$UPDATE_OUTPUT" | tee -a "$UPDATE_LOG"

# Check if update actually happened
if [ $UPDATE_EXIT -eq 0 ]; then
    # Get version after update
    VERSION_AFTER=$(openclaw update status 2>/dev/null | grep "npm latest" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

    echo "Version after update: $VERSION_AFTER" | tee -a "$UPDATE_LOG"

    # Check if version changed
    if [ "$VERSION_BEFORE" != "$VERSION_AFTER" ] && [ "$VERSION_AFTER" != "unknown" ]; then
        echo "UPDATE DETECTED: $VERSION_BEFORE → $VERSION_AFTER" | tee -a "$UPDATE_LOG"
        log_info "Update installed: $VERSION_BEFORE -> $VERSION_AFTER"

        # Update status file
        cat > "$UPDATE_STATUS" << EOF
{
  "updated": true,
  "timestamp": "$(date -Iseconds)",
  "version_before": "$VERSION_BEFORE",
  "version_after": "$VERSION_AFTER",
  "changes": []
}
EOF

        # Extract changelog if available (try to get from update output or docs)
        # For now, store version info for recap
        echo "Updated from $VERSION_BEFORE to $VERSION_AFTER" > "$CHANGES_FILE"
    else
        echo "No update needed - already on latest version" | tee -a "$UPDATE_LOG"
    fi
else
    echo "Update command failed with exit code: $UPDATE_EXIT" | tee -a "$UPDATE_LOG"
    log_error "Update command failed with exit code: $UPDATE_EXIT"
fi

echo "=== Update check complete ===" | tee -a "$UPDATE_LOG"
