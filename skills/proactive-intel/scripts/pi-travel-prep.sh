#!/bin/bash
# Proactive Intelligence — Travel Prep Monitor
# Runs daily at 9:00 AM EST via cron
# Only fires nudges when a trip is within 7 days

set -uo pipefail

# Structured logging
source /home/mccargo/.openclaw/workspace/scripts/lib/log.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/pi-nudge-engine.py"

log_info "Travel prep monitor starting"

RESULT=$(echo '{"command":"check_travel"}' | python3 "$ENGINE" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    log_error "Travel prep: nudge engine failed"
    echo '{"error": "Nudge engine failed", "success": false}'
    exit 1
fi

# Only output if there are actual travel nudges
COUNT=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null || echo "0")

if [ "$COUNT" -gt 0 ]; then
    echo "$RESULT"
    log_info "Travel prep: $COUNT upcoming trip(s) detected"
else
    log_info "Travel prep: no upcoming trips within alert window"
    echo '{"success": true, "nudges": [], "count": 0, "message": "No upcoming trips within alert window"}'
fi
