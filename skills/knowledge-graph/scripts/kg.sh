#!/bin/bash
# Knowledge Graph — Bash wrapper entry point
# Pipes JSON to kg-bridge.py for all DB operations.
#
# Usage:
#   kg.sh init
#   kg.sh upsert_entity '{"name":"John","type":"person"}'
#   kg.sh get '{"name":"John"}'
#   kg.sh query '{"type":"person","limit":10}'
#   kg.sh stale '{"days":14,"type":"person"}'
#   kg.sh stats
#   kg.sh neighbors '{"name":"Adam","hops":2}'

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE="$SCRIPT_DIR/kg-bridge.py"

# Structured logging
source /home/mccargo/.openclaw/workspace/scripts/lib/log.sh

COMMAND="${1:-}"
ARGS="${2:-"{}"}"

if [ -z "$COMMAND" ]; then
    echo '{"error": "No command provided. Usage: kg.sh <command> [json_args]", "success": false}'
    exit 1
fi

log_info "kg.sh: $COMMAND"

# Build JSON payload and pipe to bridge
PAYLOAD=$(python3 -c "
import json, sys
args = sys.argv[2] if len(sys.argv) > 2 else '{}'
print(json.dumps({'command': sys.argv[1], 'args': json.loads(args)}))
" "$COMMAND" "$ARGS" 2>&1) || {
    echo '{"error": "Invalid JSON args", "success": false}'
    log_error "kg.sh: invalid JSON args for $COMMAND"
    exit 1
}

echo "$PAYLOAD" | python3 "$BRIDGE"
