#!/bin/bash
# Shared structured logging library for OpenClaw scripts
# Source this file: source "$(dirname "$0")/lib/log.sh"
#
# Usage:
#   log_info "something happened"
#   log_warn "something concerning"
#   log_error "something broke"
#
# Writes JSON lines to a central log file for easy scanning.

OPENCLAW_LOG_DIR="${OPENCLAW_LOG_DIR:-/home/mccargo/.openclaw/workspace/logs}"
OPENCLAW_LOG_FILE="${OPENCLAW_LOG_DIR}/openclaw-events.jsonl"
OPENCLAW_SCRIPT_NAME="${OPENCLAW_SCRIPT_NAME:-$(basename "${BASH_SOURCE[1]:-unknown}" .sh)}"

mkdir -p "$OPENCLAW_LOG_DIR"

_log_event() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Write JSON line to central log
    printf '{"ts":"%s","level":"%s","script":"%s","msg":"%s"}\n' \
        "$timestamp" "$level" "$OPENCLAW_SCRIPT_NAME" "$message" \
        >> "$OPENCLAW_LOG_FILE"
}

log_info() { _log_event "info" "$1"; }
log_warn() { _log_event "warn" "$1"; }
log_error() { _log_event "error" "$1"; }
