#!/bin/bash
# OpenClaw Update Recap Script
# Runs at 7am EST, sends recap if updates occurred

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-update-recap.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of openclaw-update-recap.sh is already running. Exiting."
    exit 0
fi

WORKSPACE="/home/mccargo/.openclaw/workspace"
UPDATE_STATUS="$WORKSPACE/.update-status.json"
CHANGES_FILE="$WORKSPACE/.update-changes.txt"
LOG_DIR="$WORKSPACE/logs"
RECAP_LOG="$LOG_DIR/recap-$(date +%Y%m%d).log"

# Create logs directory
mkdir -p "$LOG_DIR"

echo "=== Update Recap - $(date) ===" | tee -a "$RECAP_LOG"

# Check if updates occurred
if [ -f "$UPDATE_STATUS" ]; then
    UPDATED=$(grep -o '"updated":[^,}]*' "$UPDATE_STATUS" | cut -d':' -f2)

    if [ "$UPDATED" = " true" ]; then
        echo "Updates were installed! Preparing recap..." | tee -a "$RECAP_LOG"

        # Extract version info
        VERSION_BEFORE=$(grep -o '"version_before":"[^"]*"' "$UPDATE_STATUS" | cut -d'"' -f4)
        VERSION_AFTER=$(grep -o '"version_after":"[^"]*"' "$UPDATE_STATUS" | cut -d'"' -f4)

        # Build recap message
        RECAP_MESSAGE="🦞 **OpenClaw Update Complete**

**Version:** $VERSION_BEFORE → $VERSION_AFTER

**Check time:** 5:00 AM EST
**Updates installed:** Yes

📋 **New Features:**
Unfortunately, the update process doesn't provide automatic changelog extraction. You can view release notes at:
https://github.com/openclaw/openclaw/releases

---

✨ System is now running latest stable version."

        echo "$RECAP_MESSAGE" | tee -a "$RECAP_LOG"

        # Send recap via OpenClaw message (to the user's session)
        # This sends to the main session, which will route to Telegram
        echo "Sending recap..." | tee -a "$RECAP_LOG"

        # Store recap for delivery
        echo "$RECAP_MESSAGE" > "$WORKSPACE/.update-recap-message.txt"

        # Reset status for next day
        echo '{"updated": false, "timestamp": null, "version_before": "", "version_after": "", "changes": []}' > "$UPDATE_STATUS"
        rm -f "$CHANGES_FILE"
    else
        echo "No updates installed today - skipping recap" | tee -a "$RECAP_LOG"
    fi
else
    echo "No update status file found - skipping recap" | tee -a "$RECAP_LOG"
fi

echo "=== Recap check complete ===" | tee -a "$RECAP_LOG"
