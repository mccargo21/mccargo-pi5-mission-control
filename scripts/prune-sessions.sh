#!/bin/bash

# Session Pruning Script
# Runs monthly to prune old session files and maintain disk space
# Respects pinned sessions listed in .pinned-sessions

set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-prune-sessions.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of prune-sessions.sh is already running. Exiting."
    exit 0
fi

# Structured logging
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

WORKSPACE="/home/mccargo/.openclaw/workspace"
LOG_FILE="$WORKSPACE/logs/maintenance.log"
PINNED_FILE="$WORKSPACE/.pinned-sessions"
PRUNE_AGE_DAYS=30
MEMORY_AGE_DAYS=60

# Create logs directory if it doesn't exist
mkdir -p "$WORKSPACE/logs"

echo "=== Session Pruning - $(date) ===" >> "$LOG_FILE"

# Load pinned session patterns (one per line, supports globs)
PINNED_PATTERNS=()
if [ -f "$PINNED_FILE" ]; then
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        PINNED_PATTERNS+=("$line")
    done < "$PINNED_FILE"
    echo "  - Loaded ${#PINNED_PATTERNS[@]} pinned session patterns" >> "$LOG_FILE"
fi

# Check if a file matches any pinned pattern
is_pinned() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    for pattern in "${PINNED_PATTERNS[@]}"; do
        # Match against filename or full path
        if [[ "$filename" == $pattern ]] || [[ "$filepath" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

# Prune agent session files (*.jsonl) older than PRUNE_AGE_DAYS, skip pinned
echo "Pruning sessions older than $PRUNE_AGE_DAYS days..." >> "$LOG_FILE"
SESSION_COUNT=0
SKIPPED_COUNT=0
while IFS= read -r session_file; do
    if is_pinned "$session_file"; then
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    else
        rm -f "$session_file"
        SESSION_COUNT=$((SESSION_COUNT + 1))
    fi
done < <(find ~/.openclaw/agents -name "*.jsonl" -mtime +$PRUNE_AGE_DAYS 2>/dev/null || true)
echo "  - Deleted $SESSION_COUNT session files" >> "$LOG_FILE"
echo "  - Skipped $SKIPPED_COUNT pinned sessions" >> "$LOG_FILE"

# Compress memory files older than MEMORY_AGE_DAYS
echo "Compressing memory files older than $MEMORY_AGE_DAYS days..." >> "$LOG_FILE"
MEMORY_COUNT=$(find "$WORKSPACE/memory" -name "*.md" -mtime +$MEMORY_AGE_DAYS 2>/dev/null | wc -l)
find "$WORKSPACE/memory" -name "*.md" -mtime +$MEMORY_AGE_DAYS -exec gzip {} \; 2>/dev/null
echo "  - Compressed $MEMORY_COUNT memory files" >> "$LOG_FILE"

# Count remaining sessions
REMAINING=$(find ~/.openclaw/agents -name "*.jsonl" 2>/dev/null | wc -l)
echo "  - Remaining sessions: $REMAINING" >> "$LOG_FILE"

log_info "Pruned $SESSION_COUNT sessions (skipped $SKIPPED_COUNT pinned), compressed $MEMORY_COUNT memory files"
echo "Pruning complete!" >> "$LOG_FILE"
echo ""
echo "Summary:"
echo "  - Sessions pruned: $SESSION_COUNT"
echo "  - Pinned sessions skipped: $SKIPPED_COUNT"
echo "  - Memory files compressed: $MEMORY_COUNT"
echo "  - Remaining sessions: $REMAINING"
