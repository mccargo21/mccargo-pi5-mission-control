#!/bin/bash
# Mission Control: Create task from chat

set -euo pipefail

TASKS_FILE="/home/mccargo/.openclaw/workspace/data/tasks.json"
TEMP_FILE=""

# Trap for cleanup
trap 'if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then rm -f "$TEMP_FILE"; fi' EXIT
TASK_ID="${1}"
TITLE="${2}"
DESCRIPTION="${3}"
STATUS="${4:-backlog}"
PROJECT="${5:-default}"
PRIORITY="${6:-medium}"

# Validate required args
if [ -z "$TASK_ID" ] || [ -z "$TITLE" ]; then
    echo "Usage: $0 <task_id> <title> [description] [status] [project] [priority]"
    exit 1
fi

# Create new task JSON
NEW_TASK=$(cat << EOF
  {
    "id": "${TASK_ID}",
    "title": "${TITLE}",
    "description": "${DESCRIPTION}",
    "status": "${STATUS}",
    "project": "${PROJECT}",
    "tags": ["chat-request"],
    "subtasks": [],
    "priority": "${PRIORITY}",
    "comments": [
      {
        "author": "Molty",
        "text": "Task created from chat request",
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      }
    ],
    "createdAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  }
EOF
)

# Insert new task into tasks array (before the closing bracket)
TEMP_FILE=$(mktemp)
jq ".tasks |= [.tasks[]] + [${NEW_TASK}] | .lastUpdated = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"" "$TASKS_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$TASKS_FILE"
# Temp file is automatically cleaned up by EXIT trap

echo "✅ Task created: $TITLE ($TASK_ID)"
echo "📋 Push to GitHub: cd /home/mccargo/.openclaw/workspace && git add data/tasks.json && git commit -m 'Add task from chat: $TITLE' && git push"
