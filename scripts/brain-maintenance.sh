#!/bin/bash
# Brain Memory Maintenance Script
# Runs weekly to decay old memories and report database stats
# Keeps the SQLite database performant by summarizing and archiving stale data

set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-brain-maintenance.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of brain-maintenance.sh is already running. Exiting."
    exit 0
fi

# Structured logging
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

WORKSPACE="/home/mccargo/.openclaw/workspace"
BRIDGE="/home/mccargo/ClawBrain/scripts/brain_bridge.py"
LOG_DIR="$WORKSPACE/logs"
LOG_FILE="$LOG_DIR/brain-maintenance-$(date +%Y%m%d).log"

mkdir -p "$LOG_DIR"

echo "=== Brain Maintenance - $(date) ===" | tee -a "$LOG_FILE"

# Step 1: Get current stats
echo "Fetching memory stats..." | tee -a "$LOG_FILE"
STATS=$(echo '{"command":"memory_stats","args":{}}' | python3 "$BRIDGE" 2>/dev/null)
echo "$STATS" | python3 -m json.tool 2>/dev/null | tee -a "$LOG_FILE"

# Step 2: Dry run first to show what would be affected
echo "" | tee -a "$LOG_FILE"
echo "Dry run - checking what would be decayed..." | tee -a "$LOG_FILE"
DRY_RUN=$(echo '{"command":"decay","args":{"dry_run":true,"summarize_days":30,"archive_days":90,"min_importance":7}}' | python3 "$BRIDGE" 2>/dev/null)
echo "$DRY_RUN" | python3 -m json.tool 2>/dev/null | tee -a "$LOG_FILE"

# Step 3: Run actual decay
echo "" | tee -a "$LOG_FILE"
echo "Running memory decay..." | tee -a "$LOG_FILE"
RESULT=$(echo '{"command":"decay","args":{"dry_run":false,"summarize_days":30,"archive_days":90,"min_importance":7}}' | python3 "$BRIDGE" 2>/dev/null)
echo "$RESULT" | python3 -m json.tool 2>/dev/null | tee -a "$LOG_FILE"

# Step 4: Post-maintenance stats
echo "" | tee -a "$LOG_FILE"
echo "Post-maintenance stats..." | tee -a "$LOG_FILE"
POST_STATS=$(echo '{"command":"memory_stats","args":{}}' | python3 "$BRIDGE" 2>/dev/null)
echo "$POST_STATS" | python3 -m json.tool 2>/dev/null | tee -a "$LOG_FILE"

# Summary for agent output
SUMMARIZED=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('summarized',0))" 2>/dev/null || echo "0")
ARCHIVED=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('archived',0))" 2>/dev/null || echo "0")
TOTAL=$(echo "$POST_STATS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('total_memories',0))" 2>/dev/null || echo "?")
DB_SIZE=$(echo "$POST_STATS" | python3 -c "import sys,json; s=json.load(sys.stdin).get('db_size_bytes',0); print(f'{s/1024/1024:.1f}MB')" 2>/dev/null || echo "?")

echo "" | tee -a "$LOG_FILE"
log_info "Brain maintenance: summarized=$SUMMARIZED archived=$ARCHIVED total=$TOTAL size=$DB_SIZE"
echo "=== Summary ===" | tee -a "$LOG_FILE"
echo "  Memories summarized: $SUMMARIZED" | tee -a "$LOG_FILE"
echo "  Memories archived:   $ARCHIVED" | tee -a "$LOG_FILE"
echo "  Total remaining:     $TOTAL" | tee -a "$LOG_FILE"
echo "  Database size:       $DB_SIZE" | tee -a "$LOG_FILE"
echo "=== Maintenance complete ===" | tee -a "$LOG_FILE"
