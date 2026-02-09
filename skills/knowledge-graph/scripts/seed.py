#!/usr/bin/env python3
"""Seed the Knowledge Graph with known entities from USER.md and MEMORY.md."""

import json
import subprocess
import sys

KG_SH = "/home/mccargo/.openclaw/workspace/skills/knowledge-graph/scripts/kg.sh"


def kg(command, args):
    result = subprocess.run(
        [KG_SH, command, json.dumps(args)],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    if not data.get("success"):
        print(f"WARN: {command} {args.get('name', '')} -> {data}", file=sys.stderr)
    return data


# ─── People ──────────────────────────────────────────────────────────────────

kg("upsert_entity", {
    "name": "Adam McCargo",
    "type": "person",
    "confidence": 1.0,
    "notes": "The boss. ~20 years marketing/communications. Media relations for travel destination. Aspiring digital marketing contractor.",
    "metadata": {
        "born": "1983-01-21",
        "important_dates": {"birthday": "01-21"},
        "education": "University of Alabama, 2002-2006",
        "hometown": "Duluth, GA",
        "pronouns": "he/him",
    }
})

kg("upsert_entity", {
    "name": "Heather McCargo",
    "type": "person",
    "confidence": 1.0,
    "notes": "Adam's wife.",
    "metadata": {
        "born": "1983-12-13",
        "important_dates": {"birthday": "12-13"},
    }
})

kg("upsert_entity", {
    "name": "William McCargo",
    "type": "person",
    "confidence": 1.0,
    "notes": "Adam's older son, 9 years old.",
    "metadata": {
        "born": "2016-03-26",
        "important_dates": {"birthday": "03-26"},
    }
})

kg("upsert_entity", {
    "name": "Joe McCargo",
    "type": "person",
    "confidence": 1.0,
    "notes": "Adam's younger son, 5 years old.",
    "metadata": {
        "born": "2020-03-08",
        "important_dates": {"birthday": "03-08"},
    }
})

# ─── Places ──────────────────────────────────────────────────────────────────

kg("upsert_entity", {
    "name": "Peachtree Corners, GA",
    "type": "place",
    "confidence": 1.0,
    "notes": "Adam's current home, just outside Atlanta.",
})

kg("upsert_entity", {
    "name": "Duluth, GA",
    "type": "place",
    "confidence": 1.0,
    "notes": "Adam's hometown.",
})

kg("upsert_entity", {
    "name": "University of Alabama",
    "type": "org",
    "confidence": 1.0,
    "notes": "Adam's alma mater, 2002-2006. Roll Tide!",
    "metadata": {"type": "university", "location": "Tuscaloosa, AL"},
})

kg("upsert_entity", {
    "name": "Cape Cod",
    "type": "place",
    "confidence": 0.8,
    "notes": "Destination for July 4 weekend 2026 trip.",
})

kg("upsert_entity", {
    "name": "Manhattan",
    "type": "place",
    "confidence": 0.8,
    "notes": "Part of Cape Cod → Manhattan fly/drive combo, July 4 2026.",
})

# ─── Events ──────────────────────────────────────────────────────────────────

kg("upsert_entity", {
    "name": "Winter Break Trip Feb 2026",
    "type": "event",
    "confidence": 1.0,
    "notes": "Family winter break trip, 4-5 days, 6-7 hour drive from Atlanta.",
    "metadata": {
        "start_date": "2026-02-12",
        "end_date": "2026-02-16",
        "participants": ["Adam", "Heather", "William", "Joe"],
    }
})

kg("upsert_entity", {
    "name": "July 4 Cape Cod Trip 2026",
    "type": "event",
    "confidence": 0.8,
    "notes": "Cape Cod → Manhattan fly/drive combo, July 4 weekend 2026.",
    "metadata": {
        "start_date": "2026-07-03",
        "end_date": "2026-07-06",
        "location": "Cape Cod, MA → Manhattan, NY",
    }
})

# ─── Projects / Aspirations ─────────────────────────────────────────────────

kg("upsert_entity", {
    "name": "Digital Marketing Contracting Business",
    "type": "project",
    "confidence": 0.9,
    "notes": "Adam's aspiration to start a digital marketing contracting business. Leverages 20 years of marketing/communications experience.",
    "metadata": {"status": "planning"},
})

# ─── Topics / Skills ────────────────────────────────────────────────────────

for topic in ["Marketing Communications", "Media Relations", "Non-Profit Direct Response",
              "Digital Communications", "Social Media", "PR", "Stakeholder Engagement",
              "Content Creation"]:
    kg("upsert_entity", {
        "name": topic,
        "type": "skill",
        "confidence": 1.0,
        "notes": f"Adam's professional expertise area.",
    })

for interest in ["Alabama Football", "Disc Golf", "3D Printing", "Gaming"]:
    kg("upsert_entity", {
        "name": interest,
        "type": "topic",
        "confidence": 1.0,
        "notes": f"Adam's personal interest.",
    })

# ─── Relationships ───────────────────────────────────────────────────────────

# Family
for member in ["Heather McCargo", "William McCargo", "Joe McCargo"]:
    kg("upsert_relation", {
        "source": "Adam McCargo",
        "target": member,
        "type": "family_of",
        "strength": 1.0,
        "bidirectional": True,
    })

# Heather <-> kids
for child in ["William McCargo", "Joe McCargo"]:
    kg("upsert_relation", {
        "source": "Heather McCargo",
        "target": child,
        "type": "family_of",
        "strength": 1.0,
        "bidirectional": True,
    })

# Siblings
kg("upsert_relation", {
    "source": "William McCargo",
    "target": "Joe McCargo",
    "type": "family_of",
    "strength": 1.0,
    "bidirectional": True,
})

# Location
kg("upsert_relation", {
    "source": "Adam McCargo",
    "target": "Peachtree Corners, GA",
    "type": "lives_in",
    "strength": 1.0,
})

# Education
kg("upsert_relation", {
    "source": "Adam McCargo",
    "target": "University of Alabama",
    "type": "attended",
    "strength": 1.0,
    "metadata": {"years": "2002-2006"},
})

# Skills
for skill in ["Marketing Communications", "Media Relations", "Non-Profit Direct Response",
              "Digital Communications", "Social Media", "PR", "Stakeholder Engagement",
              "Content Creation"]:
    kg("upsert_relation", {
        "source": "Adam McCargo",
        "target": skill,
        "type": "expert_in",
        "strength": 0.9,
    })

# Interests
for interest in ["Alabama Football", "Disc Golf", "3D Printing", "Gaming"]:
    kg("upsert_relation", {
        "source": "Adam McCargo",
        "target": interest,
        "type": "interested_in",
        "strength": 0.7,
    })

# Events
for event in ["Winter Break Trip Feb 2026", "July 4 Cape Cod Trip 2026"]:
    kg("upsert_relation", {
        "source": "Adam McCargo",
        "target": event,
        "type": "attending",
        "strength": 0.9,
    })

# Event locations
kg("upsert_relation", {
    "source": "July 4 Cape Cod Trip 2026",
    "target": "Cape Cod",
    "type": "located_in",
    "strength": 1.0,
})

# Project
kg("upsert_relation", {
    "source": "Adam McCargo",
    "target": "Digital Marketing Contracting Business",
    "type": "works_on",
    "strength": 0.8,
})

print(json.dumps({"success": True, "message": "Seed data loaded"}))
