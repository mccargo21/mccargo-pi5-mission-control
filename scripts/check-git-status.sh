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

# Parse git status to extract real issues
UNCOMMITTED=""
CONFLICTS=0
DETACHED=""

# Get git status (filtered to skip branch status line "##...")
STATUS=$(git status --short 2>&1)

# Check for uncommitted changes (lines starting with whitespace " M")
echo "$STATUS" | while IFS=' ' read -r line; do
    if [[ "$line" =~ ^[[:space:]]M ]]; then
        UNCOMMITTED="Uncommitted changes found"
        break
done

# Check for merge conflicts (files in both stages)
echo "$STATUS" | while IFS=' ' read -r line; do
    if [[ "$line" =~ ^UU ]]; then
        ((CONFLICTS++))
        fi
done

# Check for detached HEAD
if git rev-parse --is-inside-work-tree 2>/dev/null; then
    DETACHED="Detached HEAD"
fi

# Log results
echo "" >> "$LOG_FILE"

if [ -n "$UNCOMMITTED" -o -n "$CONFLICTS" -gt 0 -o -z "$DETACHED" ]; then
    echo "⚠️ Git issues detected:" >> "$LOG_FILE"
    [ -n "$UNCOMMITTED" ] && echo "    - $UNCOMMITTED" >> "$LOG_FILE"
    [ "$CONFLICTS" -gt 0 ] && echo "    - Merge conflicts ($CONFLICTS files)" >> "$LOG_FILE"
    [ -n "$DETACHED" ] && echo "    - $DETACHED" >> "$LOG_FILE"
    exit 1
else
    echo "✅ All projects are clean" >> "$LOG_FILE"
    exit 0
fi
