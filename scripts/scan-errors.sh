#!/bin/bash
# Scan central log for errors in the last 24 hours
# Outputs a summary for the agent to relay via Telegram

set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-scan-errors.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of scan-errors.sh is already running. Exiting."
    exit 0
fi

LOG_FILE="/home/mccargo/.openclaw/workspace/logs/openclaw-events.jsonl"

if [ ! -f "$LOG_FILE" ]; then
    echo "No events log found. Nothing to scan."
    exit 0
fi

CUTOFF=$(date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ")

# Extract errors and warnings from last 24h
ERRORS=$(grep '"level":"error"' "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
    ts=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ts',''))" 2>/dev/null)
    if [[ "$ts" > "$CUTOFF" ]]; then
        echo "$line"
    fi
done)

WARNS=$(grep '"level":"warn"' "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
    ts=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ts',''))" 2>/dev/null)
    if [[ "$ts" > "$CUTOFF" ]]; then
        echo "$line"
    fi
done)

ERROR_COUNT=$(echo "$ERRORS" | grep -c . 2>/dev/null || echo 0)
WARN_COUNT=$(echo "$WARNS" | grep -c . 2>/dev/null || echo 0)

if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
    echo "No errors or warnings in the last 24 hours."
    exit 0
fi

echo "=== OpenClaw Error Report (last 24h) ==="
echo ""

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "ERRORS ($ERROR_COUNT):"
    echo "$ERRORS" | while IFS= read -r line; do
        script=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  [{d.get(\"script\",\"?\")}] {d.get(\"msg\",\"?\")}')" 2>/dev/null)
        echo "$script"
    done
    echo ""
fi

if [ "$WARN_COUNT" -gt 0 ]; then
    echo "WARNINGS ($WARN_COUNT):"
    echo "$WARNS" | while IFS= read -r line; do
        script=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  [{d.get(\"script\",\"?\")}] {d.get(\"msg\",\"?\")}')" 2>/dev/null)
        echo "$script"
    done
fi
