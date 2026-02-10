#!/bin/bash
# OpenClaw Lock Library
# Provides PID-based locking to prevent stale locks after crashes
#
# Usage:
#   source "$(dirname "$0")/lib/lock.sh"
#   acquire_lock "my-script" || exit 0
#   # ... script logic ...
#   release_lock "my-script"

LOCK_DIR="${OPENCLAW_LOCK_DIR:-/tmp/openclaw-locks}"

# Ensure lock directory exists
mkdir -p "$LOCK_DIR"

# Acquire a PID-based lock
# Returns 0 on success, 1 if lock already held by running process
acquire_lock() {
    local lock_name="$1"
    local lock_file="$LOCK_DIR/${lock_name}.pid"
    local max_age="${2:-3600}"  # Default 1 hour max lock age

    # Check if lock file exists
    if [ -f "$lock_file" ]; then
        local old_pid
        old_pid=$(cat "$lock_file" 2>/dev/null) || old_pid=""

        # Check if process is still running
        if [ -n "$old_pid" ] && ps -p "$old_pid" > /dev/null 2>&1; then
            # Process is running - check how long it's been holding the lock
            local lock_age
            lock_age=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file" 2>/dev/null)
            local current_time
            current_time=$(date +%s)
            local age_seconds=$((current_time - lock_age))

            if [ "$age_seconds" -lt "$max_age" ]; then
                # Lock held by running process, not stale
                return 1
            fi
            # Lock is stale (older than max_age), will be reclaimed
        fi
        # Process not running or lock is stale - remove old lock
        rm -f "$lock_file"
    fi

    # Acquire lock by writing our PID
    echo $$ > "$lock_file"
    return 0
}

# Release a lock
release_lock() {
    local lock_name="$1"
    local lock_file="$LOCK_DIR/${lock_name}.pid"

    # Only remove if we own it (PID matches)
    if [ -f "$lock_file" ]; then
        local lock_pid
        lock_pid=$(cat "$lock_file" 2>/dev/null) || lock_pid=""
        if [ "$lock_pid" = "$$" ]; then
            rm -f "$lock_file"
        fi
    fi
}

# Setup automatic lock release on exit
# Usage: setup_auto_release "my-script"
setup_auto_release() {
    local lock_name="$1"
    trap 'release_lock "'$lock_name'"' EXIT INT TERM
}

# Legacy flock-based lock (for scripts that need file-based locking)
# This wraps flock with PID tracking for crash recovery
acquire_flock_with_pid() {
    local lock_file="$1"
    local lock_name
    lock_name=$(basename "$lock_file" .lock)
    local pid_file="$LOCK_DIR/${lock_name}.pid"

    # Try to get flock (non-blocking)
    exec 200>"$lock_file"
    if ! flock -n 200; then
        # Check if it's a stale lock
        if [ -f "$pid_file" ]; then
            local old_pid
            old_pid=$(cat "$pid_file" 2>/dev/null) || old_pid=""
            if [ -n "$old_pid" ] && ! ps -p "$old_pid" > /dev/null 2>&1; then
                # Stale lock - force acquisition
                flock -x 200
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    # Write PID for crash recovery
    echo $$ > "$pid_file"
    return 0
}
