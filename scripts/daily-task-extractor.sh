#!/bin/bash
# Daily Task Extractor - Google Calendar & Email (MCP Integration)
# Uses mcporter + Zapier MCP to fetch calendar events and emails
# Creates Mission Control tasks with auto-generated subtasks

set -euo pipefail

# Prevent overlapping runs
LOCKFILE="/tmp/openclaw-task-extractor.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
    echo "Another instance of daily-task-extractor.sh is already running. Exiting."
    exit 0
fi

# Structured logging
source "$(dirname "${BASH_SOURCE[0]}")/lib/log.sh"

WORKSPACE="/home/mccargo/.openclaw/workspace"
TASKS_FILE="$WORKSPACE/data/tasks.json"
LOG_DIR="$WORKSPACE/logs"
EXTRACTOR_LOG="$LOG_DIR/task-extractor-$(date +%Y%m%d).log"
BACKUP_FILE="$WORKSPACE/data/tasks.backup.json"
TEMP_FILE=""

# Trap for cleanup
trap 'if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then rm -f "$TEMP_FILE"; fi' EXIT

mkdir -p "$LOG_DIR"

echo "=== Daily Task Extraction - $(date) ===" | tee -a "$EXTRACTOR_LOG"

# Backup current tasks
cp "$TASKS_FILE" "$BACKUP_FILE"

# Get dates
TODAY=$(date +%Y-%m-%dT00:00:00)
NEXT_36H=$(date -d '+36 hours' +%Y-%m-%dT23:59:59)

echo "Time range: $TODAY to $NEXT_36H (36 hours)" | tee -a "$EXTRACTOR_LOG"

TASK_COUNT=0
NEW_TASKS_JSON='{"tasks": ['

echo "Step 1: Fetching Google Calendar events..." | tee -a "$EXTRACTOR_LOG"

# Get calendar events using mcporter
CALENDAR_OUTPUT=$(cd "$WORKSPACE" && timeout 30 mcporter call zapier.google_calendar_find_events instructions="Find all calendar events in the specified time range" output_hint="Return event summary with title, time, and location" start_time="$TODAY" end_time="$NEXT_36H" 2>&1)
CALENDAR_EXIT=$?

if [ $CALENDAR_EXIT -eq 0 ]; then
    echo "Calendar fetch successful" | tee -a "$EXTRACTOR_LOG"
    
    # For each calendar event, create a task
    # Simplified: create one task with all events in description
    # In production, proper JSON parsing would create separate tasks
    
    TASK_COUNT=$((TASK_COUNT + 1))
    TASK_ID="cal_$(date +%s)_$TASK_COUNT"
    
    NEW_TASKS_JSON="$NEW_TASKS_JSON
    {
      \"id\": \"$TASK_ID\",
      \"title\": \"📅 Calendar Events Today\",
      \"description\": \"Auto-extracted from Google Calendar for next 36 hours.\\n\\n**Events found:**\\n\\n$CALENDAR_OUTPUT\\n\\n**Action required:** Review events and create specific tasks if needed.\",
      \"status\": \"backlog\",
      \"project\": \"default\",
      \"tags\": [\"auto-extracted\", \"calendar\"],
      \"subtasks\": [
        { \"id\": \"sub_${TASK_ID}_1\", \"title\": \"Review calendar events\", \"done\": false },
        { \"id\": \"sub_${TASK_ID}_2\", \"title\": \"Prepare for meetings\", \"done\": false },
        { \"id\": \"sub_${TASK_ID}_3\", \"title\": \"Add follow-up tasks\", \"done\": false }
      ],
      \"priority\": \"medium\",
      \"comments\": [
        { \"author\": \"Task Extractor\", \"text\": \"Auto-generated from Google Calendar scan\", \"timestamp\": \"$(date -Iseconds)\" }
      ],
      \"createdAt\": \"$(date -Iseconds)\"
    },"
fi

echo "Step 2: Fetching emails with task keywords..." | tee -a "$EXTRACTOR_LOG"

# Search for task-related emails
EMAIL_OUTPUT=$(cd "$WORKSPACE" && timeout 30 mcporter call zapier.gmail_find_email instructions="Search Gmail for emails containing task-related keywords" output_hint="Return email subject, sender, date, and brief preview" query="(task OR to-do OR due OR deadline OR meeting OR appointment OR reminder)" max_results=10 2>&1)
EMAIL_EXIT=$?

if [ $EMAIL_EXIT -eq 0 ]; then
    echo "Email fetch successful" | tee -a "$EXTRACTOR_LOG"
    
    # Create task for email review
    TASK_COUNT=$((TASK_COUNT + 1))
    TASK_ID="email_$(date +%s)_$TASK_COUNT"
    
    NEW_TASKS_JSON="$NEW_TASKS_JSON
    {
      \"id\": \"$TASK_ID\",
      \"title\": \"📧 Review Emails for Tasks\",
      \"description\": \"Auto-extracted from Gmail search. Emails containing task keywords: task, to-do, due, deadline, meeting, appointment, reminder.\\n\\n**Emails found:**\\n\\n$EMAIL_OUTPUT\\n\\n**Action required:** Review emails and create specific tasks.\",
      \"status\": \"backlog\",
      \"project\": \"default\",
      \"tags\": [\"auto-extracted\", \"email\"],
      \"subtasks\": [
        { \"id\": \"sub_${TASK_ID}_1\", \"title\": \"Review task emails\", \"done\": false },
        { \"id\": \"sub_${TASK_ID}_2\", \"title\": \"Extract actionable items\", \"done\": false },
        { \"id\": \"sub_${TASK_ID}_3\", \"title\": \"Create specific tasks\", \"done\": false }
      ],
      \"priority\": \"medium\",
      \"comments\": [
        { \"author\": \"Task Extractor\", \"text\": \"Auto-generated from Gmail scan\", \"timestamp\": \"$(date -Iseconds)\" }
      ],
      \"createdAt\": \"$(date -Iseconds)\"
    },"
fi

echo "Step 3: Processing extracted items..." | tee -a "$EXTRACTOR_LOG"
echo "Found $TASK_COUNT tasks to add" | tee -a "$EXTRACTOR_LOG"

# Close JSON array properly
NEW_TASKS_JSON="${NEW_TASKS_JSON%,]}"
NEW_TASKS_JSON="$NEW_TASKS_JSON]}"

# Write new tasks to temp file
TEMP_FILE=$(mktemp)
echo "$NEW_TASKS_JSON" > "$TEMP_FILE"

# Merge using jq: New tasks first, then existing tasks, with timestamp
FINAL_JSON=$(jq -s --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '{tasks: (.[0].tasks + .[1].tasks), lastUpdated: $ts}' "$TEMP_FILE" "$TASKS_FILE")

echo "Step 4: Writing to tasks file..." | tee -a "$EXTRACTOR_LOG"
echo "$FINAL_JSON" > "$TASKS_FILE"

echo "Step 5: Committing to git..." | tee -a "$EXTRACTOR_LOG"

cd "$WORKSPACE"
git add data/tasks.json 2>&1 | tee -a "$EXTRACTOR_LOG"

if [ $TASK_COUNT -gt 0 ]; then
    git commit -m "Auto: Extracted $TASK_COUNT tasks from calendar & email ($TODAY)" 2>&1 | tee -a "$EXTRACTOR_LOG"
else
    echo "No tasks found, skipping commit" | tee -a "$EXTRACTOR_LOG"
fi

git push 2>&1 | tee -a "$EXTRACTOR_LOG"

if [ $? -eq 0 ]; then
    echo "✓ Tasks extracted and pushed successfully ($TASK_COUNT tasks)" | tee -a "$EXTRACTOR_LOG"
    log_info "Extracted $TASK_COUNT tasks from calendar and email"
else
    echo "✗ Failed to push tasks" | tee -a "$EXTRACTOR_LOG"
    log_error "Failed to push extracted tasks to git"
fi

echo "=== Extraction complete ===" | tee -a "$EXTRACTOR_LOG"

rm -f "$TASKS_FILE.tmp"
