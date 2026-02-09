# Knowledge Graph Schema

## Tables

### kg_entities

Primary entity store.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| name | TEXT NOT NULL | Entity name (case-insensitive unique with type) |
| type | TEXT NOT NULL | person, org, project, place, event, topic, skill |
| metadata | TEXT (JSON) | Flexible structured data |
| notes | TEXT | Free-text notes |
| confidence | REAL 0-1 | How certain we are about this entity |
| mention_count | INTEGER | Times referenced in conversation |
| first_seen | TEXT | ISO timestamp of creation |
| last_seen | TEXT | ISO timestamp of last update |
| last_mentioned | TEXT | ISO timestamp of last mention |

**Unique constraint:** `(name COLLATE NOCASE, type)`

### kg_entities_fts

FTS5 virtual table for full-text search over `name` and `notes`.

Kept in sync via INSERT/UPDATE/DELETE triggers on `kg_entities`.

### kg_relations

Relationship edges between entities.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| source_id | INTEGER FK | References kg_entities(id) CASCADE |
| target_id | INTEGER FK | References kg_entities(id) CASCADE |
| type | TEXT NOT NULL | Relationship type (knows, works_at, etc.) |
| strength | REAL 0-1 | Relationship strength |
| metadata | TEXT (JSON) | Extra context |
| bidirectional | INTEGER 0/1 | Whether the relation goes both ways |
| last_confirmed | TEXT | When this relationship was last confirmed |

**Unique constraint:** `(source_id, target_id, type)`

### kg_changelog

Lightweight audit log, auto-prunes entries older than 90 days.

| Column | Type | Description |
|--------|------|-------------|
| id | INTEGER PK | Auto-increment |
| ts | TEXT | ISO timestamp |
| action | TEXT | What happened (entity_created, entity_updated, relation_upsert, entity_deleted) |
| entity_id | INTEGER | Related entity (nullable) |
| relation_id | INTEGER | Related relation (nullable) |
| detail | TEXT | Human-readable description |

### kg_entity_summary (VIEW)

Joins entities with their relationship count for quick overview queries.

| Column | Source |
|--------|--------|
| id, name, type, confidence, mention_count, first_seen, last_seen, last_mentioned, notes | kg_entities |
| rel_count | COUNT from kg_relations |
