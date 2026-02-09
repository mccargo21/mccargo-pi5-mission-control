#!/bin/bash
# Proactive Intelligence — Relationship Review
# Runs Sundays at 10:00 AM EST via cron
# Surfaces top 3-5 stale contacts ranked by relationship strength

set -uo pipefail

# Structured logging
source /home/mccargo/.openclaw/workspace/scripts/lib/log.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/pi-nudge-engine.py"

log_info "Relationship review starting"

RESULT=$(echo '{"command":"relationship_review"}' | python3 "$ENGINE" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RESULT" ]; then
    log_error "Relationship review: nudge engine failed"
    echo '{"error": "Nudge engine failed", "success": false}'
    exit 1
fi

echo "$RESULT"
log_info "Relationship review complete"
