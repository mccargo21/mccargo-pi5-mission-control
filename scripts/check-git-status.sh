#!/bin/bash

# Git Status Check Script
# Monitors tracked projects for uncommitted changes, detached HEAD, merge conflicts

set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-git-status.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of check-git-status.sh is already running. Exiting."
    exit 0
fi

WORKSPACE="/home/mccargo/.openclaw/workspace"
LOG_FILE="$WORKSPACE/logs/git-status-$(date +%Y%m%d).log"

# Projects to monitor (add your repos here)
PROJECTS=(
    "$WORKSPACE"
)

# Create logs directory
mkdir -p "$WORKSPACE/logs"

echo "=== Git Status Check - $(date) ===" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

ANY_ISSUES=false

for proj in "${PROJECTS[@]}"; do
    proj="${proj/#\~/$HOME}"
    if [ -d "$proj/.git" ]; then
        cd "$proj" 2>/dev/null || continue

        echo "=== $(basename $proj) ===" >> "$LOG_FILE"

        # Get git status (filter out branch status line "##...")
        STATUS=$(git status --short 2>&1)
        CONFLICTS=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l)
        DETACHED=$(git branch --show-current 2>&1 | grep -q "^HEAD detached" && echo "DETECTED" || echo "")

        echo "$STATUS" >> "$LOG_FILE"

        # Check for issues
        if [ -n "$STATUS" ] || [ "$CONFLICTS" -gt 0 ] || [ -n "$DETACHED" ]; then
            ANY_ISSUES=true
            echo "  ⚠️ Issues detected:" >> "$LOG_FILE"
            [ -n "$STATUS" ] && echo "    - Uncommitted changes" >> "$LOG_FILE"
            [ "$CONFLICTS" -gt 0 ] && echo "    - Merge conflicts ($CONFLICTS files)" >> "$LOG_FILE"
            [ -n "$DETACHED" ] && echo "    - Detached HEAD" >> "$LOG_FILE"
        else
            echo "  ✅ Clean" >> "$LOG_FILE"
        fi
        echo "" >> "$LOG_FILE"
    fi
done

if [ "$ANY_ISSUES" = true ]; then
    echo "⚠️ Git issues detected in one or more projects" >> "$LOG_FILE"
    exit 1
else
    echo "✅ All projects are clean" >> "$LOG_FILE"
    exit 0
fi
