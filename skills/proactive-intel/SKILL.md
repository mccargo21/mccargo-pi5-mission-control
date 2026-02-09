---
name: proactive-intel
version: 1.0.0
description: Nudge engine that monitors the Knowledge Graph for follow-ups, stale contacts, travel prep, birthdays, and relationship insights. Use when checking what needs attention or generating morning briefings.
author: mccargo
license: MIT
tags:
  - proactive
  - nudges
  - reminders
  - intelligence
  - travel
  - contacts
keywords:
  - nudge engine
  - proactive intelligence
  - follow-up reminders
  - travel prep
  - birthday reminders
  - relationship insights
metadata:
  clawdbot:
    emoji: "🔔"
    minVersion: "1.0.0"
---

# Proactive Intelligence — Nudge Engine for Molty

Monitors the Knowledge Graph and generates actionable nudges: follow-up reminders, travel prep alerts, stale project warnings, relationship insights, and birthday reminders.

## Quick Start

```bash
# Morning briefing (KG stats + all nudges)
~/.openclaw/workspace/skills/proactive-intel/scripts/pi-morning-briefing.sh

# Relationship review (top stale contacts)
~/.openclaw/workspace/skills/proactive-intel/scripts/pi-relationship-review.sh

# Travel prep check (only fires if trip within 7 days)
~/.openclaw/workspace/skills/proactive-intel/scripts/pi-travel-prep.sh
```

## How It Works

The nudge engine reads from the Knowledge Graph database and generates prioritized nudges based on configurable rules. Each nudge type has a priority weight, and the engine caps output at 5 nudges per check (configurable).

### Nudge Types

| Type | Priority | Trigger |
|------|----------|---------|
| Birthday | 10 | `important_dates.birthday` approaching within 7 days |
| Travel prep | 9 | Event `start_date` within 7/3/1 days |
| Follow-up | 7 | Person not mentioned in 14+ days |
| Stale project | 6 | Project not updated in 10+ days |
| Relationship insight | 5 | Travel destination matches contact location |
| Opportunity | 4 | Contact needs match Adam's expertise |

## Agent Behavior

### During Morning Briefing (7:30 AM daily)
1. Run the morning briefing script
2. Present KG stats briefly (total entities/relations, new since yesterday)
3. List top nudges by priority
4. For travel prep nudges, suggest a prep checklist
5. For follow-up nudges, suggest a brief message or action

### During Relationship Review (Sundays 10:00 AM)
1. Run the relationship review script
2. Present the top 3-5 stale contacts with context
3. For each: who they are, how long since contact, shared connections
4. Suggest a specific re-engagement action for each

### During Travel Prep Check (9:00 AM daily)
1. Run the travel prep script
2. If no upcoming trips: skip silently
3. If trip detected: generate prep checklist based on trip metadata
4. At 1-day urgency: final reminder with essentials

### During Heartbeat
1. Quick stale scan: only check high-strength contacts (>= 0.7)
2. Nudge check: deliver high-priority nudges immediately, batch low-priority for morning
3. Skip if last check was < 4 hours ago (track via daily notes timestamp)

### Privacy
- Only run in main sessions (not group chats)
- Never expose contact details in group contexts
- Nudges stay local — no external notifications without Adam's approval

## Configuration

Edit `config/nudge-rules.json` to customize thresholds, quiet hours, max nudges, and priority weights. See `docs/NUDGE-TYPES.md` for full reference.

## Depends On

- **Knowledge Graph skill** — Reads entity/relation data from `~/.openclaw/workspace/skills/knowledge-graph/data/kg.sqlite`
- KG must be initialized (`kg.sh init`) before nudge engine will work

## Cron Jobs

| Job | Schedule | Script |
|-----|----------|--------|
| KG Morning Briefing | 7:30 AM daily | `pi-morning-briefing.sh` |
| Relationship Review | 10:00 AM Sundays | `pi-relationship-review.sh` |
| Travel Prep Monitor | 9:00 AM daily | `pi-travel-prep.sh` |

## Files

| File | Purpose |
|------|---------|
| `scripts/pi-nudge-engine.py` | Core engine (stdin JSON → stdout JSON) |
| `scripts/pi-morning-briefing.sh` | Morning briefing wrapper |
| `scripts/pi-relationship-review.sh` | Relationship review wrapper |
| `scripts/pi-travel-prep.sh` | Travel prep wrapper |
| `config/nudge-rules.json` | Configurable thresholds |
| `docs/NUDGE-TYPES.md` | Nudge type reference |
