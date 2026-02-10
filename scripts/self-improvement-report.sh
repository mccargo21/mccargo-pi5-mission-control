#!/bin/bash

# Self-Improvement Report Script
# Generates a report of improvements made and presents options to the user

set -euo pipefail

# Security: PID-based locking prevents stale locks after crashes
source "$(dirname "${BASH_SOURCE[0]}")/lib/lock.sh"

if ! acquire_lock "self-improvement-report" 1800; then
    echo "Another instance of self-improvement-report.sh is already running. Exiting."
    exit 0
fi

setup_auto_release "self-improvement-report"

WORKSPACE="/home/mccargo/.openclaw/workspace"
TIMESTAMP=$(date +%Y-%m-%d\ %H:%M:%S)
REPORT_FILE="/tmp/self-improvement-report-$$.txt"
CHANGES_FILE="/tmp/self-improvement-changes-$$.txt"

# Generate changes list
cd "$WORKSPACE"

echo "=== Self-Improvement Report - $TIMESTAMP ===" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check for new or modified files
echo "📋 Files Changed/Added:" >> "$REPORT_FILE"
if git -C "$WORKSPACE" status --porcelain 2>/dev/null; then
    git -C "$WORKSPACE" status --porcelain >> "$REPORT_FILE"
else
    echo "   (Git not initialized or no changes)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Check for new skills
echo "🧠 New Skills:" >> "$REPORT_FILE"
if ls "$WORKSPACE"/skills/*/SKILL.md 1>/dev/null 2>&1; then
    for skill in "$WORKSPACE"/skills/*/SKILL.md; do
        skill_name=$(basename $(dirname "$skill"))
        echo "   - $skill_name" >> "$REPORT_FILE"
    done
else
    echo "   (No new skills)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Check for MCP updates
echo "🔌 MCP Tools Updated:" >> "$REPORT_FILE"
if [ -f "/home/mccargo/.openclaw/workspace/config/mcporter.json" ]; then
    # Security: Use --cacert or ensure system CA store is used properly
    # --max-time prevents hanging on slow connections
    # --retry provides resilience for transient failures
    curl -s --max-time 10 --retry 2 https://mcp.zapier.com/api/v1/tools 2>/dev/null | jq -r '.[] | select(.id | contains("zapier")) | .name' | while read tool; do
        echo "   - $tool" >> "$CHANGES_FILE"
    done
    if [ -s "$CHANGES_FILE" ]; then
        cat "$CHANGES_FILE" >> "$REPORT_FILE"
    else
        echo "   (No MCP tools list available)" >> "$REPORT_FILE"
    fi
    rm "$CHANGES_FILE"
else
    echo "   (MCP config not found)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Check for config changes
echo "⚙️ Configuration Changes:" >> "$REPORT_FILE"
if [ -f "/home/mccargo/.openclaw/workspace/config/model-routing.md" ]; then
    echo "   - Model routing rules updated" >> "$REPORT_FILE"
fi
if [ -f "/home/mccargo/.openclaw/workspace/config/zai-models.md" ]; then
    echo "   - Z.ai models list updated" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Present options
cat >> "$REPORT_FILE" << 'EOF'

🚀 Available Actions:
   [1] VIEW FULL REPORT
   [2] ROLLBACK ALL CHANGES (git reset --hard HEAD)
   [3] PUSH FOR MORE LIKE THIS UPDATE (spawn self-improvement sub-agent)
   [4] SKIP FOR NOW
EOF

echo "" >> "$REPORT_FILE"
echo "Generated at: $TIMESTAMP" >> "$REPORT_FILE"

# Display report
cat "$REPORT_FILE"

# Clean up
rm "$REPORT_FILE"

echo ""
echo "To take action, reply with your choice (1-4)"
