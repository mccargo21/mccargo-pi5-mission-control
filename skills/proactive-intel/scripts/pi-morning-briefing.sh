#!/bin/bash
# Proactive Intelligence — Morning Briefing
# Runs daily at 7:30 AM EST via cron
# Generates KG stats + stale contacts + calendar + nudges

set -uo pipefail

# Structured logging
source /home/mccargo/.openclaw/workspace/scripts/lib/log.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/pi-nudge-engine.py"

log_info "Morning briefing starting"

RESULT=$(echo '{"command":"morning_briefing"}' | python3 "$ENGINE" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    log_error "Morning briefing: nudge engine failed"
    echo '{"error": "Nudge engine failed", "success": false}'
    exit 1
fi

echo "$RESULT"
log_info "Morning briefing complete"
