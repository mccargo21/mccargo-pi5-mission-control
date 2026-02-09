#!/usr/bin/env python3
"""
Proactive Intelligence — Nudge Engine

Reads the Knowledge Graph and generates actionable nudges:
- Follow-up reminders for stale contacts
- Travel prep alerts for upcoming events
- Stale project warnings
- Relationship insights (contacts near travel destinations)
- Opportunity matching (contact needs vs Adam's expertise)
- Birthday/important date reminders

Usage:
    echo '{"command":"check_all"}' | python3 pi-nudge-engine.py
    echo '{"command":"check_followups"}' | python3 pi-nudge-engine.py
    echo '{"command":"check_travel"}' | python3 pi-nudge-engine.py
    echo '{"command":"check_birthdays"}' | python3 pi-nudge-engine.py
    echo '{"command":"morning_briefing"}' | python3 pi-nudge-engine.py
    echo '{"command":"relationship_review"}' | python3 pi-nudge-engine.py
"""

import sys
import json
from pathlib import Path
from datetime import datetime, timezone

# Add KG scripts to path for shared DB access
KG_SCRIPTS = Path(__file__).parent.parent.parent / "knowledge-graph" / "scripts"
sys.path.insert(0, str(KG_SCRIPTS))

from kg_lib import get_cursor, log_event, utcnow  # noqa: E402

# ─── Config ──────────────────────────────────────────────────────────────────

CONFIG_FILE = Path(__file__).parent.parent / "config" / "nudge-rules.json"
DEFAULT_CONFIG = {
    "stale_thresholds_days": {
        "person": 14,
        "project": 10,
        "org": 30,
        "event": 7,
    },
    "travel_alert_days": [7, 3, 1],
    "birthday_alert_days": 7,
    "quiet_hours": {"start": 23, "end": 8},
    "max_nudges_per_day": 5,
    "priority_weights": {
        "birthday": 10,
        "travel_prep": 9,
        "follow_up": 7,
        "stale_project": 6,
        "relationship_insight": 5,
        "opportunity": 4,
    },
    "min_strength_for_followup": 0.5,
}


def load_config():
    try:
        with open(CONFIG_FILE) as f:
            user_config = json.load(f)
        # Deep merge: preserve nested defaults that user didn't override
        config = {}
        for key, default_val in DEFAULT_CONFIG.items():
            user_val = user_config.get(key)
            if isinstance(default_val, dict) and isinstance(user_val, dict):
                merged = default_val.copy()
                merged.update(user_val)
                config[key] = merged
            elif user_val is not None:
                config[key] = user_val
            else:
                config[key] = default_val
        return config
    except (FileNotFoundError, json.JSONDecodeError):
        return DEFAULT_CONFIG.copy()


def is_quiet_hours(config):
    """Check if current local time is within quiet hours."""
    from zoneinfo import ZoneInfo
    now = datetime.now(ZoneInfo("America/New_York"))
    hour = now.hour
    start = config["quiet_hours"]["start"]
    end = config["quiet_hours"]["end"]
    if start > end:  # e.g., 23:00 - 08:00
        return hour >= start or hour < end
    return start <= hour < end


# ─── Nudge Generators ───────────────────────────────────────────────────────

def check_followups(cur, config):
    """People not mentioned in N days, ranked by relationship strength."""
    threshold = config["stale_thresholds_days"]["person"]
    min_strength = config["min_strength_for_followup"]

    rows = cur.execute("""
        SELECT e.id, e.name, e.notes, e.last_mentioned, e.mention_count,
               MAX(r.strength) AS max_strength
        FROM kg_entities e
        LEFT JOIN kg_relations r ON (r.source_id = e.id OR r.target_id = e.id)
        WHERE e.type = 'person'
          AND e.name != 'Adam McCargo'
          AND e.last_mentioned < datetime('now', ?)
        GROUP BY e.id
        HAVING max_strength >= ? OR max_strength IS NULL
        ORDER BY max_strength DESC, e.last_mentioned ASC
    """, (f"-{threshold} days", min_strength)).fetchall()

    nudges = []
    for r in rows:
        days_ago = _days_since(r["last_mentioned"])
        nudges.append({
            "type": "follow_up",
            "priority": config["priority_weights"]["follow_up"],
            "entity_id": r["id"],
            "entity_name": r["name"],
            "message": f"You haven't mentioned {r['name']} in {days_ago} days.",
            "detail": r["notes"] or "",
            "strength": r["max_strength"] or 0,
            "days_stale": days_ago,
        })
    return nudges


def check_travel(cur, config):
    """Event entities with dates within alert windows."""
    nudges = []
    alert_days = config["travel_alert_days"]
    max_days = max(alert_days)

    rows = cur.execute("""
        SELECT e.id, e.name, e.notes, e.metadata
        FROM kg_entities e
        WHERE e.type = 'event'
    """).fetchall()

    today = datetime.now(timezone.utc).date()

    for r in rows:
        meta = r["metadata"]
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except (json.JSONDecodeError, TypeError):
                continue

        start_str = meta.get("start_date")
        if not start_str:
            continue

        try:
            start_date = datetime.strptime(start_str, "%Y-%m-%d").date()
        except ValueError:
            continue

        days_until = (start_date - today).days
        if 0 <= days_until <= max_days:
            # Find matching alert threshold
            for threshold in sorted(alert_days):
                if days_until <= threshold:
                    urgency = "imminent" if days_until <= 1 else (
                        "soon" if days_until <= 3 else "upcoming"
                    )
                    nudges.append({
                        "type": "travel_prep",
                        "priority": config["priority_weights"]["travel_prep"] + (
                            3 if days_until <= 1 else (1 if days_until <= 3 else 0)
                        ),
                        "entity_id": r["id"],
                        "entity_name": r["name"],
                        "message": f"{r['name']} is in {days_until} day{'s' if days_until != 1 else ''} — {urgency}!",
                        "detail": r["notes"] or "",
                        "days_until": days_until,
                        "urgency": urgency,
                        "metadata": meta,
                    })
                    break
    return nudges


def check_stale_projects(cur, config):
    """Projects not updated in N days."""
    threshold = config["stale_thresholds_days"]["project"]

    rows = cur.execute("""
        SELECT e.id, e.name, e.notes, e.last_mentioned, e.metadata
        FROM kg_entities e
        WHERE e.type = 'project'
          AND e.last_mentioned < datetime('now', ?)
    """, (f"-{threshold} days",)).fetchall()

    nudges = []
    for r in rows:
        days_ago = _days_since(r["last_mentioned"])
        meta = r["metadata"]
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except (json.JSONDecodeError, TypeError):
                meta = {}

        status = meta.get("status", "unknown")
        nudges.append({
            "type": "stale_project",
            "priority": config["priority_weights"]["stale_project"],
            "entity_id": r["id"],
            "entity_name": r["name"],
            "message": f"Project \"{r['name']}\" hasn't been updated in {days_ago} days (status: {status}).",
            "detail": r["notes"] or "",
            "days_stale": days_ago,
            "status": status,
        })
    return nudges


def check_birthdays(cur, config):
    """People with birthdays approaching within N days."""
    alert_days = config["birthday_alert_days"]
    today = datetime.now(timezone.utc).date()

    rows = cur.execute("""
        SELECT e.id, e.name, e.metadata
        FROM kg_entities e
        WHERE e.type = 'person'
          AND json_extract(e.metadata, '$.important_dates.birthday') IS NOT NULL
    """).fetchall()

    nudges = []
    for r in rows:
        meta = r["metadata"]
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except (json.JSONDecodeError, TypeError):
                continue

        bday_str = meta.get("important_dates", {}).get("birthday")
        if not bday_str:
            continue

        try:
            month, day = map(int, bday_str.split("-"))
            from datetime import date
            bday_this_year = date(today.year, month, day)
            days_until = (bday_this_year - today).days
            # Handle already passed this year
            if days_until < 0:
                bday_next_year = date(today.year + 1, month, day)
                days_until = (bday_next_year - today).days
        except (ValueError, TypeError):
            continue

        if 0 <= days_until <= alert_days:
            nudges.append({
                "type": "birthday",
                "priority": config["priority_weights"]["birthday"],
                "entity_id": r["id"],
                "entity_name": r["name"],
                "message": f"{r['name']}'s birthday is in {days_until} day{'s' if days_until != 1 else ''}!",
                "days_until": days_until,
            })
    return nudges


def check_relationship_insights(cur, config):
    """Find contacts near upcoming travel destinations."""
    nudges = []

    # Get upcoming events with locations
    events = cur.execute("""
        SELECT e.id, e.name, e.metadata
        FROM kg_entities e
        WHERE e.type = 'event'
    """).fetchall()

    today = datetime.now(timezone.utc).date()

    for event in events:
        meta = event["metadata"]
        if isinstance(meta, str):
            try:
                meta = json.loads(meta)
            except (json.JSONDecodeError, TypeError):
                continue

        start_str = meta.get("start_date")
        location = meta.get("location", "")
        if not start_str or not location:
            continue

        try:
            start_date = datetime.strptime(start_str, "%Y-%m-%d").date()
        except ValueError:
            continue

        days_until = (start_date - today).days
        if days_until < 0 or days_until > 30:
            continue

        # Search for people connected to places matching the location
        # Check place entities that match location keywords
        location_words = [w.strip().lower() for w in location.replace("→", ",").split(",") if len(w.strip()) > 2]

        for word in location_words:
            places = cur.execute("""
                SELECT e.id FROM kg_entities e
                WHERE e.type = 'place' AND LOWER(e.name) LIKE ?
            """, (f"%{word}%",)).fetchall()

            for place in places:
                # Find people connected to this place
                people = cur.execute("""
                    SELECT e.name, r.type
                    FROM kg_relations r
                    JOIN kg_entities e ON (
                        (r.source_id = e.id AND r.target_id = ?) OR
                        (r.target_id = e.id AND r.source_id = ?)
                    )
                    WHERE e.type = 'person' AND e.name != 'Adam McCargo'
                """, (place["id"], place["id"])).fetchall()

                if people:
                    names = [p["name"] for p in people]
                    nudges.append({
                        "type": "relationship_insight",
                        "priority": config["priority_weights"]["relationship_insight"],
                        "entity_name": event["name"],
                        "message": f"You know {len(names)} people near {word.title()}: {', '.join(names)}",
                        "contacts": names,
                        "destination": word.title(),
                        "days_until_trip": days_until,
                    })
    return nudges


def morning_briefing(cur, config):
    """Comprehensive morning summary: stats + stale + travel + birthdays + nudges."""
    stats_row = cur.execute("SELECT COUNT(*) as cnt FROM kg_entities").fetchone()
    rel_row = cur.execute("SELECT COUNT(*) as cnt FROM kg_relations").fetchone()

    type_counts = {}
    for row in cur.execute("SELECT type, COUNT(*) as cnt FROM kg_entities GROUP BY type"):
        type_counts[row["type"]] = row["cnt"]

    # Gather all nudges
    all_nudges = []
    all_nudges.extend(check_followups(cur, config))
    all_nudges.extend(check_travel(cur, config))
    all_nudges.extend(check_stale_projects(cur, config))
    all_nudges.extend(check_birthdays(cur, config))
    all_nudges.extend(check_relationship_insights(cur, config))

    # Sort by priority descending
    all_nudges.sort(key=lambda n: n["priority"], reverse=True)

    # Cap at max nudges
    max_nudges = config["max_nudges_per_day"]
    top_nudges = all_nudges[:max_nudges]

    return {
        "success": True,
        "type": "morning_briefing",
        "timestamp": utcnow(),
        "stats": {
            "total_entities": stats_row["cnt"],
            "total_relations": rel_row["cnt"],
            "by_type": type_counts,
        },
        "nudges": top_nudges,
        "total_nudges_available": len(all_nudges),
        "nudges_shown": len(top_nudges),
    }


def relationship_review(cur, config):
    """Weekly deep-dive: top 3-5 stale contacts ranked by strength."""
    threshold = config["stale_thresholds_days"]["person"]
    min_strength = config["min_strength_for_followup"]

    rows = cur.execute("""
        SELECT e.id, e.name, e.notes, e.last_mentioned, e.mention_count,
               e.metadata,
               MAX(r.strength) AS max_strength,
               GROUP_CONCAT(DISTINCT t.name) AS connected_to
        FROM kg_entities e
        LEFT JOIN kg_relations r ON (r.source_id = e.id OR r.target_id = e.id)
        LEFT JOIN kg_entities t ON (
            (r.source_id = t.id AND t.id != e.id) OR
            (r.target_id = t.id AND t.id != e.id)
        )
        WHERE e.type = 'person'
          AND e.name != 'Adam McCargo'
          AND e.last_mentioned < datetime('now', ?)
        GROUP BY e.id
        HAVING max_strength >= ? OR max_strength IS NULL
        ORDER BY max_strength DESC, e.last_mentioned ASC
        LIMIT 5
    """, (f"-{threshold} days", min_strength)).fetchall()

    contacts = []
    for r in rows:
        contacts.append({
            "name": r["name"],
            "notes": r["notes"] or "",
            "last_mentioned": r["last_mentioned"],
            "days_stale": _days_since(r["last_mentioned"]),
            "mention_count": r["mention_count"],
            "strength": r["max_strength"] or 0,
            "connected_to": (r["connected_to"] or "").split(",")[:5],
        })

    return {
        "success": True,
        "type": "relationship_review",
        "timestamp": utcnow(),
        "stale_contacts": contacts,
        "count": len(contacts),
    }


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _days_since(iso_ts):
    """Calculate days since an ISO timestamp."""
    if not iso_ts:
        return 999
    try:
        then = datetime.fromisoformat(iso_ts.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        return (now - then).days
    except (ValueError, TypeError):
        return 999


# ─── Dispatch ────────────────────────────────────────────────────────────────

def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        log_event("error", "Invalid JSON input", "pi-nudge-engine")
        print(json.dumps({"error": "Invalid JSON input", "success": False}))
        return

    command = input_data.get("command", "")
    config = load_config()

    log_event("info", f"Nudge engine: {command}", "pi-nudge-engine")

    try:
        with get_cursor() as cur:
            if command == "check_all":
                nudges = []
                nudges.extend(check_followups(cur, config))
                nudges.extend(check_travel(cur, config))
                nudges.extend(check_stale_projects(cur, config))
                nudges.extend(check_birthdays(cur, config))
                nudges.extend(check_relationship_insights(cur, config))
                nudges.sort(key=lambda n: n["priority"], reverse=True)
                max_n = config["max_nudges_per_day"]
                result = {
                    "success": True,
                    "nudges": nudges[:max_n],
                    "total": len(nudges),
                    "shown": min(len(nudges), max_n),
                }

            elif command == "check_followups":
                nudges = check_followups(cur, config)
                result = {"success": True, "nudges": nudges, "count": len(nudges)}

            elif command == "check_travel":
                nudges = check_travel(cur, config)
                result = {"success": True, "nudges": nudges, "count": len(nudges)}

            elif command == "check_birthdays":
                nudges = check_birthdays(cur, config)
                result = {"success": True, "nudges": nudges, "count": len(nudges)}

            elif command == "check_stale_projects":
                nudges = check_stale_projects(cur, config)
                result = {"success": True, "nudges": nudges, "count": len(nudges)}

            elif command == "check_insights":
                nudges = check_relationship_insights(cur, config)
                result = {"success": True, "nudges": nudges, "count": len(nudges)}

            elif command == "morning_briefing":
                result = morning_briefing(cur, config)

            elif command == "relationship_review":
                result = relationship_review(cur, config)

            else:
                result = {"error": f"Unknown command: {command}", "success": False}

        print(json.dumps(result, default=str))

    except Exception as e:
        log_event("error", str(e), "pi-nudge-engine")
        print(json.dumps({"error": str(e), "success": False}))


if __name__ == "__main__":
    main()
