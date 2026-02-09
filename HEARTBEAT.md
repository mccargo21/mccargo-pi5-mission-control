# HEARTBEAT.md

# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.

### Git Status Check
1. Run ~/.openclaw/workspace/scripts/check-git-status.sh
2. Flag any:
   - Uncommitted changes in tracked projects
   - Detached HEAD states
   - Merge conflicts
3. If any found, mention them briefly
4. If nothing to report, continue with other checks

### Backup Morning Briefing Check (Fallback if cron fails)
# If current time is between 7:35 AM and 9:00 AM EST AND no briefing was sent today
# 1. Check ~/.openclaw/workspace/.last-morning-briefing.timestamp
# 2. If timestamp doesn't exist or is not from today, run:
#    - bash ~/.openclaw/workspace/skills/proactive-intel/scripts/pi-morning-briefing.sh
# 3. Update timestamp file with current date
# 4. Present the briefing results
# This runs ONLY on heartbeat polls during the 7:35-9:00 AM window
