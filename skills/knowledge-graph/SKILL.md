---
name: knowledge-graph
version: 1.0.0
description: Entity/relationship knowledge graph for people, orgs, projects, places, events, topics, and skills. Use when tracking contacts, relationships, or structured facts about Adam's world.
author: mccargo
license: MIT
tags:
  - knowledge-graph
  - entities
  - relationships
  - contacts
  - memory
keywords:
  - knowledge graph
  - entity extraction
  - relationship tracking
  - contact management
  - structured memory
metadata:
  clawdbot:
    emoji: "🕸️"
    minVersion: "1.0.0"
---

# Knowledge Graph — Structured Memory for Molty

A SQLite-backed entity/relationship store for people, organizations, projects, places, events, topics, and skills. Complements MEMORY.md (prose) with structured, queryable data.

## Quick Start

```bash
# Initialize the database (idempotent)
~/.openclaw/workspace/skills/knowledge-graph/scripts/kg.sh init

# Add an entity
kg.sh upsert_entity '{"name":"John Smith","type":"person","notes":"Met at Travel Weekly conference","confidence":0.9}'

# Add a relationship
kg.sh upsert_relation '{"source":"Adam McCargo","target":"John Smith","type":"knows","strength":0.6}'

# Search
kg.sh query '{"type":"person","text":"travel"}'

# Get entity with all relationships
kg.sh get '{"name":"John Smith"}'
```

## Commands

| Command | Args | Purpose |
|---------|------|---------|
| `init` | — | Create schema (safe to re-run) |
| `upsert_entity` | name, type, notes?, metadata?, confidence? | Create or update entity (bumps mention_count) |
| `upsert_relation` | source, target, type, strength?, bidirectional?, metadata? | Create or update relationship |
| `query` | type?, text?, metadata?, limit?, offset? | Search entities |
| `get` | id or name | Get entity + all relationships with resolved names |
| `stats` | — | Counts by type, most connected, most stale |
| `stale` | days?, type? | Entities not mentioned in N days |
| `neighbors` | id or name, hops?, filter_type? | Entities within N hops |
| `delete_entity` | id or name | Remove entity and its relations |

## Entity Types

| Type | Examples |
|------|----------|
| `person` | Contacts, family, colleagues |
| `org` | Companies, associations, publications |
| `project` | Marketing campaigns, business ventures |
| `place` | Cities, venues, destinations |
| `event` | Trips, conferences, deadlines |
| `topic` | Interests, expertise areas |
| `skill` | Technical or professional capabilities |

## Relationship Types

Common patterns (not exhaustive — use whatever fits):

| Type | Use for |
|------|---------|
| `family_of` | Family relationships (bidirectional) |
| `works_at` | Employment |
| `works_with` | Professional collaboration |
| `knows` | General acquaintance |
| `lives_in` | Person → Place |
| `located_in` | Org/Event → Place |
| `part_of` | Sub-org, sub-project |
| `interested_in` | Person → Topic |
| `expert_in` | Person → Skill/Topic |
| `attended` | Person → Event |
| `organizes` | Person/Org → Event |

## When to Extract Entities

**DO extract** when Adam:
- Mentions a new person by name with context ("I talked to Sarah from Travel Weekly")
- Shares organizational info ("We're partnering with XYZ Corp")
- Discusses projects with substance ("The LinkedIn A/B test showed 15% lift")
- Mentions travel plans with dates/places
- Reveals professional connections between people

**DO NOT extract** when:
- The mention is casual/passing with no new info
- The entity is already in the graph and no new details are provided
- In group chats (privacy — main sessions only)
- The information is speculative or unconfirmed (unless flagged with low confidence)

## Confidence Scoring

| Confidence | When to use |
|------------|-------------|
| 0.8 - 1.0 | Adam directly stated it ("John works at Travel Weekly") |
| 0.5 - 0.7 | Implied from context ("I'll email John about the article" → knows) |
| 0.3 - 0.5 | Inferred/guessed ("Sarah mentioned budgets" → maybe works in finance) |

## Metadata Conventions

Store structured fields in the `metadata` JSON:

**Person:** `{"title": "...", "email": "...", "phone": "...", "important_dates": {"birthday": "MM-DD"}, "linkedin": "..."}`

**Org:** `{"industry": "...", "url": "...", "size": "..."}`

**Event:** `{"start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "location": "..."}`

**Project:** `{"status": "active|paused|completed", "url": "..."}`

## Extraction Workflow

When you detect substantive entity info in conversation:

1. Call `kg.sh upsert_entity` for each new/updated entity
2. Call `kg.sh upsert_relation` for any relationships
3. Briefly note the extraction in today's daily notes: `KG: Added [name] ([type]) — [1-line reason]`
4. Do NOT interrupt the conversation flow — extract silently and continue

## Database

- **Location:** `~/.openclaw/workspace/skills/knowledge-graph/data/kg.sqlite`
- **Separate from main.sqlite** — no upgrade conflicts
- **FTS5** for fast text search over entity names and notes
- **Changelog** auto-prunes at 90 days

## Files

| File | Purpose |
|------|---------|
| `scripts/kg.sh` | Bash entry point |
| `scripts/kg-bridge.py` | All DB operations (stdin JSON → stdout JSON) |
| `scripts/kg-lib.py` | Shared DB connection helpers |
| `data/kg.sqlite` | Database (created by `init`) |
| `docs/SCHEMA.md` | Full schema documentation |
