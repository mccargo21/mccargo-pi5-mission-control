#!/bin/bash
# Mission Control Task Update Script
# Usage: mc-update.sh <command> <task_id> [args...]
#
# Commands:
#   status <task_id> <new_status>       - Update task status (backlog, in_progress, review, done)
#   subtask <task_id> <subtask_id> done - Mark subtask as done
#   comment <task_id> "comment text"    - Add comment to task
#   add-subtask <task_id> "title"       - Add new subtask
#   complete <task_id> "summary"        - Move to review + add completion comment
#   start <task_id>                     - Mark as being processed (prevents duplicate processing)

set -e

# Input validation function - prevents shell injection and malicious input
validate_input() {
    local input="$1"
    local field_name="${2:-input}"

    # Check for empty input
    if [ -z "$input" ]; then
        echo "❌ Error: $field_name cannot be empty" >&2
        return 1
    fi

    # Security: Enhanced validation for IDs (alphanumeric, dash, underscore only)
    if [ "$field_name" = "task_id" ] || [ "$field_name" = "subtask_id" ]; then
        if ! echo "$input" | grep -qE '^[a-zA-Z0-9_-]+$'; then
            echo "❌ Error: $field_name contains invalid characters" >&2
            echo "   Only alphanumeric, dash, and underscore allowed" >&2
            return 1
        fi
    fi

    # Check for shell injection patterns
    if echo "$input" | grep -qE '[;&|$\(]'; then
        echo "❌ Error: $field_name contains invalid characters" >&2
        echo "   Forbidden characters: ; & | $ ( )" >&2
        return 1
    fi

    # Check for command substitution patterns
    if echo "$input" | grep -qE '\$\(|\\$'; then
        echo "❌ Error: $field_name contains command substitution patterns" >&2
        return 1
    fi

    # Security: Check for Python injection patterns (single quotes, triple quotes)
    if echo "$input" | grep -qE "'''|\"\"\""; then
        echo "❌ Error: $field_name contains Python quote sequences" >&2
        return 1
    fi

    # Check length limits
    local max_length=10000
    if [ ${#input} -gt $max_length ]; then
        echo "❌ Error: $field_name exceeds maximum length of $max_length characters" >&2
        return 1
    fi

    return 0
}

# Validate status values
validate_status() {
    local status="$1"
    case "$status" in
        backlog|in_progress|review|done) ;;
        *)
            echo "❌ Error: Invalid status '$status'" >&2
            echo "   Valid values: backlog, in_progress, review, done" >&2
            return 1
            ;;
    esac
    return 0
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TASKS_FILE="$REPO_DIR/data/tasks.json"

cd "$REPO_DIR"

case "$1" in
    status)
        TASK_ID="$2"
        NEW_STATUS="$3"

        if [[ -z "$TASK_ID" || -z "$NEW_STATUS" ]]; then
            echo "Usage: mc-update.sh status <task_id> <new_status>"
            exit 1
        fi

        # Validate inputs
        validate_input "$TASK_ID" "task_id" || exit 1
        validate_status "$NEW_STATUS" || exit 1

        # Security: Pass data via environment variables to avoid shell injection in heredoc
        export MC_TASK_ID="$TASK_ID"
        export MC_NEW_STATUS="$NEW_STATUS"
        export MC_TASKS_FILE="$TASKS_FILE"

        python3 << 'PYEOF'
import json
import os

TASK_ID = os.environ['MC_TASK_ID']
NEW_STATUS = os.environ['MC_NEW_STATUS']
TASKS_FILE = os.environ['MC_TASKS_FILE']

with open(TASKS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)
found = False
for t in data['tasks']:
    if t['id'] == TASK_ID:
        old_status = t['status']
        t['status'] = NEW_STATUS
        found = True
        print(f"✓ {t['title']}: {old_status} → {NEW_STATUS}")
        break
if not found:
    print(f"✗ Task '{TASK_ID}' not found")
    exit(1)
with open(TASKS_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
        ;;

    subtask)
        TASK_ID="$2"
        SUBTASK_ID="$3"
        ACTION="$4"

        if [[ -z "$TASK_ID" || -z "$SUBTASK_ID" || "$ACTION" != "done" ]]; then
            echo "Usage: mc-update.sh subtask <task_id> <subtask_id> done"
            exit 1
        fi

        # Validate inputs
        validate_input "$TASK_ID" "task_id" || exit 1
        validate_input "$SUBTASK_ID" "subtask_id" || exit 1

        # Security: Pass via environment variables
        export MC_TASK_ID="$TASK_ID"
        export MC_SUBTASK_ID="$SUBTASK_ID"
        export MC_TASKS_FILE="$TASKS_FILE"

        python3 << 'PYEOF'
import json
import os

TASK_ID = os.environ['MC_TASK_ID']
SUBTASK_ID = os.environ['MC_SUBTASK_ID']
TASKS_FILE = os.environ['MC_TASKS_FILE']

with open(TASKS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)
found = False
for t in data['tasks']:
    if t['id'] == TASK_ID:
        for s in t['subtasks']:
            if s['id'] == SUBTASK_ID:
                s['done'] = True
                found = True
                print(f"✓ Subtask '{s['title']}' marked as done")
                break
        break
if not found:
    print(f"✗ Task or subtask not found")
    exit(1)
with open(TASKS_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
        ;;

    comment)
        TASK_ID="$2"
        COMMENT_TEXT="$3"

        if [[ -z "$TASK_ID" || -z "$COMMENT_TEXT" ]]; then
            echo "Usage: mc-update.sh comment <task_id> \"comment text\""
            exit 1
        fi

        # Validate inputs
        validate_input "$TASK_ID" "task_id" || exit 1
        validate_input "$COMMENT_TEXT" "comment_text" || exit 1

        # Security: Pass via environment variables
        export MC_TASK_ID="$TASK_ID"
        export MC_COMMENT_TEXT="$COMMENT_TEXT"
        export MC_TASKS_FILE="$TASKS_FILE"

        python3 << 'PYEOF'
import json
import os
from datetime import datetime

TASK_ID = os.environ['MC_TASK_ID']
COMMENT_TEXT = os.environ['MC_COMMENT_TEXT']
TASKS_FILE = os.environ['MC_TASKS_FILE']

with open(TASKS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)
found = False
for t in data['tasks']:
    if t['id'] == TASK_ID:
        if 'comments' not in t:
            t['comments'] = []
        comment = {
            'id': f"c{len(t['comments'])+1}",
            'author': 'MoltBot',
            'text': COMMENT_TEXT,
            'createdAt': datetime.now().isoformat() + 'Z'
        }
        t['comments'].append(comment)
        found = True
        print(f"✓ Comment added to '{t['title']}'")
        break
if not found:
    print(f"✗ Task '{TASK_ID}' not found")
    exit(1)
with open(TASKS_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
        ;;

    add-subtask)
        TASK_ID="$2"
        SUBTASK_TITLE="$3"

        if [[ -z "$TASK_ID" || -z "$SUBTASK_TITLE" ]]; then
            echo "Usage: mc-update.sh add-subtask <task_id> \"subtask title\""
            exit 1
        fi

        # Validate inputs
        validate_input "$TASK_ID" "task_id" || exit 1
        validate_input "$SUBTASK_TITLE" "subtask_title" || exit 1

        # Security: Pass via environment variables
        export MC_TASK_ID="$TASK_ID"
        export MC_SUBTASK_TITLE="$SUBTASK_TITLE"
        export MC_TASKS_FILE="$TASKS_FILE"

        python3 << 'PYEOF'
import json
import os

TASK_ID = os.environ['MC_TASK_ID']
SUBTASK_TITLE = os.environ['MC_SUBTASK_TITLE']
TASKS_FILE = os.environ['MC_TASKS_FILE']

with open(TASKS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)
found = False
for t in data['tasks']:
    if t['id'] == TASK_ID:
        subtask_id = f"sub_{len(t['subtasks'])+1}"
        t['subtasks'].append({
            'id': subtask_id,
            'title': SUBTASK_TITLE,
            'done': False
        })
        found = True
        print(f"✓ Subtask '{subtask_id}' added to '{t['title']}'")
        break
if not found:
    print(f"✗ Task '{TASK_ID}' not found")
    exit(1)
with open(TASKS_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
        ;;

    complete)
        TASK_ID="$2"
        SUMMARY="$3"

        if [[ -z "$TASK_ID" || -z "$SUMMARY" ]]; then
            echo "Usage: mc-update.sh complete <task_id> \"summary of what was done\""
            exit 1
        fi

        # Validate inputs
        validate_input "$TASK_ID" "task_id" || exit 1
        validate_input "$SUMMARY" "summary" || exit 1

        # Security: Pass via environment variables
        export MC_TASK_ID="$TASK_ID"
        export MC_SUMMARY="$SUMMARY"
        export MC_TASKS_FILE="$TASKS_FILE"

        python3 << 'PYEOF'
import json
import os
from datetime import datetime

TASK_ID = os.environ['MC_TASK_ID']
SUMMARY = os.environ['MC_SUMMARY']
TASKS_FILE = os.environ['MC_TASKS_FILE']

with open(TASKS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)
found = False
for t in data['tasks']:
    if t['id'] == TASK_ID:
        old_status = t['status']
        t['status'] = 'review'
        # Clear processing flag (stops spinner)
        if 'processingStartedAt' in t:
            del t['processingStartedAt']
        if 'comments' not in t:
            t['comments'] = []
        comment = {
            'id': f"c{len(t['comments'])+1}",
            'author': 'MoltBot',
            'text': SUMMARY,
            'createdAt': datetime.now().isoformat() + 'Z'
        }
        t['comments'].append(comment)
        found = True
        print(f"✓ {t['title']}: {old_status} → review")
        print(f"✓ Added completion comment")
        break
if not found:
    print(f"✗ Task '{TASK_ID}' not found")
    exit(1)
with open(TASKS_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
        ;;

    start)
        TASK_ID="$2"

        if [[ -z "$TASK_ID" ]]; then
            echo "Usage: mc-update.sh start <task_id>"
            exit 1
        fi

        # Validate inputs
        validate_input "$TASK_ID" "task_id" || exit 1

        # Security: Pass via environment variables
        export MC_TASK_ID="$TASK_ID"
        export MC_TASKS_FILE="$TASKS_FILE"

        python3 << 'PYEOF'
import json
import os
from datetime import datetime

TASK_ID = os.environ['MC_TASK_ID']
TASKS_FILE = os.environ['MC_TASKS_FILE']

with open(TASKS_FILE, 'r', encoding='utf-8') as f:
    data = json.load(f)
found = False
for t in data['tasks']:
    if t['id'] == TASK_ID:
        # Check if already being processed
        if t.get('processingStartedAt'):
            print(f"⚠ Task '{t['title']}' is already being processed since {t['processingStartedAt']}")
            exit(1)
        
        # Set processing timestamp
        now = datetime.now().isoformat() + 'Z'
        t['processingStartedAt'] = now
        
        # Add comment
        if 'comments' not in t:
            t['comments'] = []
        comment = {
            'id': f"c_{int(datetime.now().timestamp()*1000)}",
            'author': 'MoltBot',
            'text': '🤖 Processing started',
            'createdAt': now
        }
        t['comments'].append(comment)
        
        found = True
        print(f"✓ Processing started for '{t['title']}'")
        print(f"✓ processingStartedAt: {now}")
        break
if not found:
    print(f"✗ Task '{TASK_ID}' not found")
    exit(1)
with open(TASKS_FILE, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
PYEOF
        ;;
        
    *)
        echo "Mission Control Task Update Script"
        echo ""
        echo "Usage: mc-update.sh <command> <task_id> [args...]"
        echo ""
        echo "Commands:"
        echo "  status <task_id> <new_status>       - Update task status"
        echo "  subtask <task_id> <subtask_id> done - Mark subtask as done"
        echo "  comment <task_id> \"text\"            - Add comment to task"
        echo "  add-subtask <task_id> \"title\"       - Add new subtask"
        echo "  complete <task_id> \"summary\"        - Move to review + add comment"
        echo "  start <task_id>                     - Mark as being processed (prevents duplicates)"
        exit 1
        ;;
esac

# Auto commit and push if changes were made
if [[ -n "$(git status --porcelain data/tasks.json)" ]]; then
    git add data/tasks.json
    git commit -m "Task update via mc-update.sh: $1 $2"
    git push
    echo "✓ Changes pushed to GitHub"
fi
