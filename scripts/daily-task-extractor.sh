#!/bin/bash
# Daily Task Extractor - Google Calendar & Email (MCP Integration)
# Uses mcporter + Zapier MCP to fetch calendar events and emails
# Creates Mission Control tasks with auto-generated subtasks

set -euo pipefail

# Security: PID-based locking prevents stale locks after crashes
source "$(dirname "${BASH_SOURCE[0]}")/lib/lock.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

if ! acquire_lock "daily-task-extractor" 3600; then
    log_warn "Another instance is running or lock is stale (< 1 hour old)"
    exit 0
fi

setup_auto_release "daily-task-extractor"

WORKSPACE="/home/mccargo/.openclaw/workspace"
TASKS_FILE="$WORKSPACE/data/tasks.json"
LOG_DIR="$WORKSPACE/logs"
EXTRACTOR_LOG="$LOG_DIR/task-extractor-$(date +%Y%m%d).log"
BACKUP_FILE="$WORKSPACE/data/tasks.backup.json"
TEMP_FILE=""

# Trap for cleanup
trap 'if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then rm -f "$TEMP_FILE"; fi' EXIT

mkdir -p "$LOG_DIR"

# Security: Set restrictive permissions on log files to protect PII
chmod 600 "$LOG_DIR"/task-extractor-*.log 2>/dev/null || true

# Security: Sanitize logs - don't include raw calendar/email content
sanitize_log() {
    # Log success/failure only, not the actual content
    echo "$1"
}

echo "=== Daily Task Extraction - $(date) ===" >> "$EXTRACTOR_LOG"

# Backup current tasks
cp "$TASKS_FILE" "$BACKUP_FILE"

# Get dates
TODAY=$(date +%Y-%m-%dT00:00:00)
NEXT_36H=$(date -d '+36 hours' +%Y-%m-%dT23:59:59)

echo "Time range: $TODAY to $NEXT_36H (36 hours)" >> "$EXTRACTOR_LOG"

TASK_COUNT=0
NEW_TASKS_JSON='{"tasks": ['

echo "Step 1: Fetching Google Calendar events..." >> "$EXTRACTOR_LOG"

# Alert configuration
ALERT_ON_FAILURE=true

# Get calendar events using mcporter
CALENDAR_OUTPUT=$(cd "$WORKSPACE" && timeout 30 mcporter call zapier.google_calendar_find_events instructions="Find all calendar events in the specified time range" output_hint="Return event summary with title, time, and location" start_time="$TODAY" end_time="$NEXT_36H" 2>&1)
CALENDAR_EXIT=$?

if [ $CALENDAR_EXIT -eq 0 ]; then
    # Security: Don't log calendar content (PII)
    echo "Calendar fetch successful ($(echo "$CALENDAR_OUTPUT" | wc -l) lines)" >> "$EXTRACTOR_LOG"

    TASK_COUNT=$((TASK_COUNT + 1))
    TASK_ID="cal_$(date +%s)_$TASK_COUNT"

    # Build task JSON using jq to properly escape all special characters
    NEW_TASKS_JSON=$(jq -n \
        --arg id "$TASK_ID" \
        --arg cal_output "$CALENDAR_OUTPUT" \
        --arg ts "$(date -Iseconds)" \
        '{
            id: $id,
            title: "📅 Calendar Events Today",
            description: ("Auto-extracted from Google Calendar for next 36 hours.\n\n**Events found:**\n\n" + $cal_output + "\n\n**Action required:** Review events and create specific tasks if needed."),
            status: "backlog",
            project: "default",
            tags: ["auto-extracted", "calendar"],
            subtasks: [
                {id: ("sub_" + $id + "_1"), title: "Review calendar events", done: false},
                {id: ("sub_" + $id + "_2"), title: "Prepare for meetings", done: false},
                {id: ("sub_" + $id + "_3"), title: "Add follow-up tasks", done: false}
            ],
            priority: "medium",
            comments: [
                {author: "Task Extractor", text: "Auto-generated from Google Calendar scan", timestamp: $ts}
            ],
            createdAt: $ts
        }' <<< "")

    NEW_TASKS_JSON="{\"tasks\": [$NEW_TASKS_JSON,"
else
    # Security: Log error without exposing sensitive details
    echo "ERROR: Calendar fetch failed (exit code: $CALENDAR_EXIT)" >> "$EXTRACTOR_LOG"
    log_error "Calendar fetch failed with exit code $CALENDAR_EXIT"
    if [ "$ALERT_ON_FAILURE" = true ]; then
        # Create error task for visibility
        TASK_COUNT=$((TASK_COUNT + 1))
        TASK_ID="error_cal_$(date +%s)"
        ERROR_TASK=$(jq -n \
            --arg id "$TASK_ID" \
            --arg ts "$(date -Iseconds)" \
            --arg error "Calendar API call failed (exit $CALENDAR_EXIT)" \
            '{
                id: $id,
                title: "⚠️ Error: Calendar Fetch Failed",
                description: ("Failed to fetch calendar events.\n\nError: " + $error + "\n\n**Action required:** Check mcporter/Zapier connectivity."),
                status: "backlog",
                project: "default",
                tags: ["error", "auto-extracted", "calendar"],
                subtasks: [],
                priority: "high",
                comments: [
                    {author: "Task Extractor", text: "Auto-generated error report", timestamp: $ts}
                ],
                createdAt: $ts
            }' <<< "")
        NEW_TASKS_JSON="{\"tasks\": [$ERROR_TASK,"
    fi
fi

echo "Step 2: Fetching emails with task keywords..." >> "$EXTRACTOR_LOG"

# Search for task-related emails
EMAIL_OUTPUT=$(cd "$WORKSPACE" && timeout 30 mcporter call zapier.gmail_find_email instructions="Search Gmail for emails containing task-related keywords" output_hint="Return email subject, sender, date, and brief preview" query="(task OR to-do OR due OR deadline OR meeting OR appointment OR reminder)" max_results=10 2>&1)
EMAIL_EXIT=$?

if [ $EMAIL_EXIT -eq 0 ]; then
    # Security: Don't log email content (PII)
    echo "Email fetch successful ($(echo "$EMAIL_OUTPUT" | wc -l) lines)" >> "$EXTRACTOR_LOG"

    TASK_COUNT=$((TASK_COUNT + 1))
    TASK_ID="email_$(date +%s)_$TASK_COUNT"

    # Build task JSON using jq to properly escape all special characters
    EMAIL_TASK=$(jq -n \
        --arg id "$TASK_ID" \
        --arg email_output "$EMAIL_OUTPUT" \
        --arg ts "$(date -Iseconds)" \
        '{
            id: $id,
            title: "📧 Review Emails for Tasks",
            description: ("Auto-extracted from Gmail search. Emails containing task keywords: task, to-do, due, deadline, meeting, appointment, reminder.\n\n**Emails found:**\n\n" + $email_output + "\n\n**Action required:** Review emails and create specific tasks."),
            status: "backlog",
            project: "default",
            tags: ["auto-extracted", "email"],
            subtasks: [
                {id: ("sub_" + $id + "_1"), title: "Review task emails", done: false},
                {id: ("sub_" + $id + "_2"), title: "Extract actionable items", done: false},
                {id: ("sub_" + $id + "_3"), title: "Create specific tasks", done: false}
            ],
            priority: "medium",
            comments: [
                {author: "Task Extractor", text: "Auto-generated from Gmail scan", timestamp: $ts}
            ],
            createdAt: $ts
        }' <<< "")

    if [ -n "$NEW_TASKS_JSON" ]; then
        NEW_TASKS_JSON="${NEW_TASKS_JSON}${EMAIL_TASK},"
    else
        NEW_TASKS_JSON="{\"tasks\": [${EMAIL_TASK},"
    fi
else
    # Security: Log error without exposing sensitive details
    echo "ERROR: Email fetch failed (exit code: $EMAIL_EXIT)" >> "$EXTRACTOR_LOG"
    log_error "Email fetch failed with exit code $EMAIL_EXIT"
    if [ "$ALERT_ON_FAILURE" = true ]; then
        # Create error task for visibility
        TASK_COUNT=$((TASK_COUNT + 1))
        TASK_ID="error_email_$(date +%s)"
        ERROR_TASK=$(jq -n \
            --arg id "$TASK_ID" \
            --arg ts "$(date -Iseconds)" \
            --arg error "Gmail API call failed (exit $EMAIL_EXIT)" \
            '{
                id: $id,
                title: "⚠️ Error: Email Fetch Failed",
                description: ("Failed to fetch task-related emails.\n\nError: " + $error + "\n\n**Action required:** Check mcporter/Zapier connectivity and Gmail API permissions."),
                status: "backlog",
                project: "default",
                tags: ["error", "auto-extracted", "email"],
                subtasks: [],
                priority: "high",
                comments: [
                    {author: "Task Extractor", text: "Auto-generated error report", timestamp: $ts}
                ],
                createdAt: $ts
            }' <<< "")
        if [ -n "$NEW_TASKS_JSON" ]; then
            NEW_TASKS_JSON="${NEW_TASKS_JSON}${ERROR_TASK},"
        else
            NEW_TASKS_JSON="{\"tasks\": [${ERROR_TASK},"
        fi
    fi
fi

echo "Step 3: Processing extracted items..." >> "$EXTRACTOR_LOG"
echo "Found $TASK_COUNT tasks to add" >> "$EXTRACTOR_LOG"

# Close JSON array properly
if [ $TASK_COUNT -gt 0 ]; then
    NEW_TASKS_JSON="${NEW_TASKS_JSON%,}]}"
else
    NEW_TASKS_JSON='{"tasks": []}'
fi

# Write new tasks to temp file
TEMP_FILE=$(mktemp)
echo "$NEW_TASKS_JSON" > "$TEMP_FILE"

# Merge using jq: New tasks first, then existing tasks, with timestamp
FINAL_JSON=$(jq -s --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '{tasks: (.[0].tasks + .[1].tasks), lastUpdated: $ts}' "$TEMP_FILE" "$TASKS_FILE")

echo "Step 4: Writing to tasks file..." >> "$EXTRACTOR_LOG"
echo "$FINAL_JSON" > "$TASKS_FILE"

echo "Step 5: Committing to git..." >> "$EXTRACTOR_LOG"

cd "$WORKSPACE"
git add data/tasks.json 2>&1 >> "$EXTRACTOR_LOG"

if [ $TASK_COUNT -gt 0 ]; then
    git commit -m "Auto: Extracted $TASK_COUNT tasks from calendar & email ($TODAY)" 2>&1 >> "$EXTRACTOR_LOG"
else
    echo "No tasks found, skipping commit" >> "$EXTRACTOR_LOG"
fi

git push 2>&1 >> "$EXTRACTOR_LOG"

# Generate enhanced daily briefing
BRIEFING_ID="briefing_$(date +%s)"
BRIEFING_TITLE="Daily Context Briefing"
BRIEFING_DESC="Enhanced morning briefing with trip overview, weather, priorities, and resource links"

# Create briefing task (after all extraction tasks are added)
echo "Step 6: Generating daily briefing..." >> "$EXTRACTOR_LOG"

# Get current weather (Islamorada forecast - simple placeholder)
WEATHER="☀️ **Weather:** Islamorada, FL - Feb 11-14, 2026\\nCheck forecast before packing"

# Build trip overview
TRIP_OVERVIEW="## 🌴 Trip Overview\\n\\n**Traveling to:** Islamorada, FL (Feb 11-14)\\n**Duration:** 3 nights\\n**Travelers:** Adam, William (9), Joseph (5)\\n**Accommodation:** Amara Cay Resort\\n**Transportation:** Frontier Airlines + Flexways rental\\n\\n✅ All bookings confirmed!"

# Priorities from calendar (placeholder - will enhance later)
PRIORITIES="\\n## 🎯 Top 3 Priorities\\n\\nReviewing calendar for today's priorities..."

# Family context
FAMILY_CONTEXT="\\n## 👨 Family Context\\n\\nTraveling with kids - plan age-appropriate activities for William (9) and Joseph (5)."

# Resource links
RESOURCES="\\n## 📋 Quick Resources\\n\\n- Flight: UH51YJ (Frontier)\\n- Hotel: 77821SG427107 (Amara Cay)\\n- Car: NM1TUD (Flexways)\\n- Documents folder link"

# Personal tip
TIP="\\n## 💡 Personal/Pro Tip\\n\\nWeather in Islamorada in Feb is pleasant (65-72°F). Pack layers!"

# Construct briefing task
BRIEFING_TASK="{
  \"id\": \"$BRIEFING_ID\",
  \"title\": \"$BRIEFING_TITLE\",
  \"description\": \"$TRIP_OVERVIEW\\n\\n$PRIORITIES\\n\\n$FAMILY_CONTEXT\\n\\n$RESOURCES\\n\\n$TIP\",
  \"status\": \"backlog\",
  \"project\": \"default\",
  \"tags\": [\"daily-briefing\", \"context\", \"weather\"],
  \"subtasks\": [],
  \"priority\": \"high\",
  \"comments\": [
    { \"author\": \"Task Extractor\", \"text\": \"Auto-generated daily briefing with trip context\", \"timestamp\": \"$(date -Iseconds)\" }
  ],
  \"createdAt\": \"$(date -Iseconds)\"
}"

echo "Step 7: Adding briefing task to final JSON..." >> "$EXTRACTOR_LOG"

# Add briefing task to tasks.json
UPDATED_JSON=$(jq --argjson briefing "$BRIEFING_TASK" '.tasks += [$briefing]' "$TASKS_FILE")
echo "$UPDATED_JSON" > "$TASKS_FILE"

# Commit the briefing task
git add data/tasks.json 2>&1 >> "$EXTRACTOR_LOG"
git commit -m "Auto: Added daily briefing task ($BRIEFING_ID)" 2>&1 >> "$EXTRACTOR_LOG"
git push 2>&1 >> "$EXTRACTOR_LOG"

if [ $? -eq 0 ]; then
    echo "✓ Tasks extracted and pushed successfully ($TASK_COUNT tasks)" >> "$EXTRACTOR_LOG"
    log_info "Extracted $TASK_COUNT tasks from calendar and email"
else
    echo "✗ Failed to push tasks" >> "$EXTRACTOR_LOG"
    log_error "Failed to push extracted tasks to git"
fi

echo "=== Extraction complete ===" >> "$EXTRACTOR_LOG"

rm -f "$TASKS_FILE.tmp"
