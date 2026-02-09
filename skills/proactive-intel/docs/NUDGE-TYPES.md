# Nudge Types

## Overview

The Proactive Intelligence engine generates nudges — actionable reminders and insights — by monitoring the Knowledge Graph and calendar data.

## Nudge Types

### Follow-up (priority: 7)
**Trigger:** Person entity not mentioned in 14+ days (configurable)
**Filter:** Only contacts with relationship strength >= 0.5
**Example:** "You haven't mentioned John Smith in 2 weeks."

### Travel Prep (priority: 9)
**Trigger:** Event entity with `start_date` in metadata within 7/3/1 days
**Urgency levels:** upcoming (7d), soon (3d), imminent (1d)
**Example:** "Winter Break Trip is in 3 days — soon!"

### Stale Project (priority: 6)
**Trigger:** Project entity not updated in 10+ days (configurable)
**Example:** "Project 'LinkedIn A/B Test' hasn't been updated in 15 days (status: active)."

### Relationship Insight (priority: 5)
**Trigger:** Travel destination matches a place connected to known contacts
**Example:** "You know 3 people near Miami: Sarah, John, Mike"

### Opportunity (priority: 4)
**Trigger:** Contact's noted needs match Adam's expertise areas
**Example:** "Sarah needs marketing help — your sweet spot!"
**Note:** Requires `needs` field in contact metadata

### Birthday (priority: 10)
**Trigger:** `important_dates.birthday` in entity metadata approaching within 7 days
**Example:** "Heather's birthday is in 3 days!"

## Configuration

Edit `config/nudge-rules.json` to customize:

- **stale_thresholds_days** — How long before each entity type is considered stale
- **travel_alert_days** — Days before trip to trigger alerts (array)
- **birthday_alert_days** — Days before birthday to alert
- **quiet_hours** — No nudges during these hours (23:00-08:00 default)
- **max_nudges_per_day** — Cap on total nudges (default: 5)
- **priority_weights** — Relative priority for ranking/sorting
- **min_strength_for_followup** — Minimum relationship strength to trigger follow-up nudges

## Commands

| Command | Output |
|---------|--------|
| `check_all` | All nudge types, sorted by priority, capped at max |
| `check_followups` | Stale contact nudges only |
| `check_travel` | Travel prep nudges only |
| `check_birthdays` | Birthday nudges only |
| `check_stale_projects` | Stale project nudges only |
| `check_insights` | Relationship insight nudges only |
| `morning_briefing` | Full briefing: KG stats + all nudges |
| `relationship_review` | Top 5 stale contacts with details |
