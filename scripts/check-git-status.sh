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

# Change to workspace before running git commands
cd "$WORKSPACE" || exit 1

# Get git status (filtered to skip branch status line "##...")
STATUS=$(git status --short 2>&1)

# Check for staged modifications (M at start of line - indicates changes that should be committed)
if echo "$STATUS" | grep -qE '^M '; then
    UNCOMMITTED="Staged changes not committed"
fi

# Check for merge conflicts (all unmerged states: DD, AU, UD, UA, DU, AA, UU)
CONFLICTS=$(echo "$STATUS" | grep -cE '^(DD|AU|UA|DU|UD|AA|UU) ' || true)

# Check for detached HEAD
if git rev-parse --is-inside-work-tree 2>/dev/null && git symbolic-ref --quiet HEAD >/dev/null 2>&1; then
    DETACHED=""
else
    if git rev-parse --is-inside-work-tree 2>/dev/null; then
        DETACHED="Detached HEAD"
    fi
fi

# Log results
echo "" >> "$LOG_FILE"

HAS_ISSUES=0

if [ -n "$UNCOMMITTED" ] || [ "$CONFLICTS" -gt 0 ] || [ -n "$DETACHED" ]; then
    HAS_ISSUES=1
    echo "⚠️ Git issues detected:" >> "$LOG_FILE"
    [ -n "$UNCOMMITTED" ] && echo "    - $UNCOMMITTED" >> "$LOG_FILE"
    [ "$CONFLICTS" -gt 0 ] && echo "    - Merge conflicts ($CONFLICTS files)" >> "$LOG_FILE"
    [ -n "$DETACHED" ] && echo "    - $DETACHED" >> "$LOG_FILE"
fi

if [ "$HAS_ISSUES" -eq 1 ]; then
    exit 1
else
    echo "✅ All projects are clean" >> "$LOG_FILE"
    exit 0
fi
