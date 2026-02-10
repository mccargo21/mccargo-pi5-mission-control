#!/usr/bin/env python3
"""
Knowledge Graph Bridge — All DB operations.

Receives JSON commands via stdin, outputs JSON results via stdout.
Matches the brain_bridge.py protocol used elsewhere in OpenClaw.

Usage:
    echo '{"command": "init", "args": {}}' | python3 kg-bridge.py
    echo '{"command": "upsert_entity", "args": {"name": "John", "type": "person"}}' | python3 kg-bridge.py
"""

import sys
import json
import re
from pathlib import Path

# Add scripts dir to path so kg-lib is importable
sys.path.insert(0, str(Path(__file__).parent))

from kg_lib import get_cursor, log_event, utcnow  # noqa: E402

# ─── Schema ──────────────────────────────────────────────────────────────────

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS kg_entities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN (
        'person','org','project','place','event','topic','skill'
    )),
    metadata TEXT DEFAULT '{}',
    notes TEXT DEFAULT '',
    confidence REAL DEFAULT 0.8 CHECK(confidence >= 0 AND confidence <= 1),
    mention_count INTEGER DEFAULT 1,
    first_seen TEXT NOT NULL,
    last_seen TEXT NOT NULL,
    last_mentioned TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_entity_name_type
    ON kg_entities(name COLLATE NOCASE, type);

CREATE INDEX IF NOT EXISTS idx_entity_type ON kg_entities(type);
CREATE INDEX IF NOT EXISTS idx_entity_last_mentioned ON kg_entities(last_mentioned);

-- FTS5 virtual table for fast text search over name + notes
CREATE VIRTUAL TABLE IF NOT EXISTS kg_entities_fts USING fts5(
    name, notes, content=kg_entities, content_rowid=id
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS kg_entities_ai AFTER INSERT ON kg_entities BEGIN
    INSERT INTO kg_entities_fts(rowid, name, notes)
    VALUES (new.id, new.name, new.notes);
END;

CREATE TRIGGER IF NOT EXISTS kg_entities_ad AFTER DELETE ON kg_entities BEGIN
    INSERT INTO kg_entities_fts(kg_entities_fts, rowid, name, notes)
    VALUES ('delete', old.id, old.name, old.notes);
END;

CREATE TRIGGER IF NOT EXISTS kg_entities_au AFTER UPDATE ON kg_entities BEGIN
    INSERT INTO kg_entities_fts(kg_entities_fts, rowid, name, notes)
    VALUES ('delete', old.id, old.name, old.notes);
    INSERT INTO kg_entities_fts(rowid, name, notes)
    VALUES (new.id, new.name, new.notes);
END;

CREATE TABLE IF NOT EXISTS kg_relations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id INTEGER NOT NULL REFERENCES kg_entities(id) ON DELETE CASCADE,
    target_id INTEGER NOT NULL REFERENCES kg_entities(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    strength REAL DEFAULT 0.5 CHECK(strength >= 0 AND strength <= 1),
    metadata TEXT DEFAULT '{}',
    bidirectional INTEGER DEFAULT 0,
    last_confirmed TEXT NOT NULL,
    UNIQUE(source_id, target_id, type)
);

CREATE INDEX IF NOT EXISTS idx_rel_source ON kg_relations(source_id);
CREATE INDEX IF NOT EXISTS idx_rel_target ON kg_relations(target_id);
CREATE INDEX IF NOT EXISTS idx_rel_type ON kg_relations(type);

CREATE TABLE IF NOT EXISTS kg_changelog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    action TEXT NOT NULL,
    entity_id INTEGER,
    relation_id INTEGER,
    detail TEXT DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_changelog_ts ON kg_changelog(ts);

-- Auto-prune changelog entries older than 90 days on each insert
CREATE TRIGGER IF NOT EXISTS kg_changelog_prune AFTER INSERT ON kg_changelog BEGIN
    DELETE FROM kg_changelog
    WHERE ts < datetime('now', '-90 days');
END;

-- Convenience view: entity with relationship counts
CREATE VIEW IF NOT EXISTS kg_entity_summary AS
SELECT
    e.id, e.name, e.type, e.confidence, e.mention_count,
    e.first_seen, e.last_seen, e.last_mentioned, e.notes,
    (SELECT COUNT(*) FROM kg_relations r
     WHERE r.source_id = e.id OR r.target_id = e.id) AS rel_count
FROM kg_entities e;
"""


# ─── Commands ────────────────────────────────────────────────────────────────

def cmd_init(args, cur):
    """Create schema (idempotent)."""
    cur.executescript(SCHEMA_SQL)
    return {"success": True, "message": "Schema initialized"}


def cmd_upsert_entity(args, cur):
    """Create or update entity. Bumps mention_count if exists."""
    name = args.get("name", "").strip()
    etype = args.get("type", "").strip()
    if not name or not etype:
        return {"success": False, "error": "name and type are required"}

    now = utcnow()
    metadata = json.dumps(args.get("metadata", {}))
    notes = args.get("notes", "")
    confidence = args.get("confidence", 0.8)

    # Try update first
    cur.execute("""
        UPDATE kg_entities
        SET metadata = CASE WHEN ? != '{}' THEN ? ELSE metadata END,
            notes = CASE WHEN ? != '' THEN ? ELSE notes END,
            confidence = MAX(confidence, ?),
            mention_count = mention_count + 1,
            last_seen = ?,
            last_mentioned = ?
        WHERE name = ? COLLATE NOCASE AND type = ?
    """, (metadata, metadata, notes, notes, confidence, now, now, name, etype))

    if cur.rowcount == 0:
        cur.execute("""
            INSERT INTO kg_entities (name, type, metadata, notes, confidence,
                                     mention_count, first_seen, last_seen, last_mentioned)
            VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?)
        """, (name, etype, metadata, notes, confidence, now, now, now))
        entity_id = cur.lastrowid
        action = "created"
    else:
        cur.execute(
            "SELECT id FROM kg_entities WHERE name = ? COLLATE NOCASE AND type = ?",
            (name, etype)
        )
        entity_id = cur.fetchone()["id"]
        action = "updated"

    # Changelog
    cur.execute(
        "INSERT INTO kg_changelog (ts, action, entity_id, detail) VALUES (?, ?, ?, ?)",
        (now, f"entity_{action}", entity_id, f"{etype}: {name}")
    )

    return {"success": True, "id": entity_id, "action": action, "name": name, "type": etype}


def cmd_upsert_relation(args, cur):
    """Create or update relationship between two entities."""
    source = args.get("source_id") or args.get("source")
    target = args.get("target_id") or args.get("target")
    rtype = args.get("type", "").strip()
    if not source or not target or not rtype:
        return {"success": False, "error": "source, target, and type are required"}

    # Resolve names to IDs if strings provided
    source_id = _resolve_entity(cur, source)
    target_id = _resolve_entity(cur, target)
    if source_id is None:
        return {"success": False, "error": f"Source entity not found: {source}"}
    if target_id is None:
        return {"success": False, "error": f"Target entity not found: {target}"}

    now = utcnow()
    strength = args.get("strength", 0.5)
    metadata = json.dumps(args.get("metadata", {}))
    bidirectional = 1 if args.get("bidirectional", False) else 0

    cur.execute("""
        INSERT INTO kg_relations (source_id, target_id, type, strength, metadata,
                                  bidirectional, last_confirmed)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(source_id, target_id, type) DO UPDATE SET
            strength = MAX(kg_relations.strength, excluded.strength),
            metadata = CASE WHEN excluded.metadata != '{}' THEN excluded.metadata
                       ELSE kg_relations.metadata END,
            bidirectional = excluded.bidirectional,
            last_confirmed = excluded.last_confirmed
    """, (source_id, target_id, rtype, strength, metadata, bidirectional, now))

    rel_id = cur.execute(
        "SELECT id FROM kg_relations WHERE source_id=? AND target_id=? AND type=?",
        (source_id, target_id, rtype)
    ).fetchone()["id"]

    cur.execute(
        "INSERT INTO kg_changelog (ts, action, relation_id, detail) VALUES (?, ?, ?, ?)",
        (now, "relation_upsert", rel_id, f"{source} --[{rtype}]--> {target}")
    )

    return {"success": True, "id": rel_id, "source_id": source_id,
            "target_id": target_id, "type": rtype}


def cmd_query(args, cur):
    """Search entities by type, FTS text, metadata, limit/offset."""
    conditions = []
    params = []

    etype = args.get("type")
    if etype:
        conditions.append("e.type = ?")
        params.append(etype)

    text = args.get("text", "").strip()
    if text:
        # Use FTS5 for text search
        cur.execute(
            "SELECT rowid FROM kg_entities_fts WHERE kg_entities_fts MATCH ?",
            (text,)
        )
        fts_ids = [row["rowid"] for row in cur.fetchall()]
        if not fts_ids:
            return {"success": True, "entities": [], "total": 0}
        placeholders = ",".join("?" * len(fts_ids))
        conditions.append(f"e.id IN ({placeholders})")
        params.extend(fts_ids)

    metadata_filter = args.get("metadata")
    if metadata_filter and isinstance(metadata_filter, dict):
        # Security: Additional reserved key check to prevent prototype pollution
        RESERVED_KEYS = {'__proto__', 'constructor', 'prototype'}
        for key, value in metadata_filter.items():
            # Sanitize key: only allow alphanumeric, underscore, dot, hyphen
            if not re.match(r'^[a-zA-Z0-9_.\-]+$', key):
                continue
            # Block reserved keys that could cause prototype pollution
            if key.lower() in RESERVED_KEYS or key.startswith('__'):
                continue
            # Additional safety: validate JSON path is simple (no functions)
            if not re.match(r'^[a-zA-Z0-9_.\-]+$', str(value)):
                # Value contains special chars - use parameterized query only
                pass
            conditions.append("json_extract(e.metadata, ?) = ?")
            params.append(f"$.{key}")
            params.append(value)

    where = (" WHERE " + " AND ".join(conditions)) if conditions else ""
    limit = args.get("limit", 50)
    offset = args.get("offset", 0)

    count_row = cur.execute(
        f"SELECT COUNT(*) as cnt FROM kg_entities e{where}", params
    ).fetchone()
    total = count_row["cnt"]

    rows = cur.execute(f"""
        SELECT e.id, e.name, e.type, e.metadata, e.notes, e.confidence,
               e.mention_count, e.first_seen, e.last_seen, e.last_mentioned
        FROM kg_entities e{where}
        ORDER BY e.last_mentioned DESC
        LIMIT ? OFFSET ?
    """, params + [limit, offset]).fetchall()

    entities = [_row_to_dict(r) for r in rows]
    return {"success": True, "entities": entities, "total": total}


def cmd_get(args, cur):
    """Get a single entity with all its relationships (resolved names)."""
    entity_id = args.get("id")
    name = args.get("name")

    if entity_id:
        row = cur.execute("SELECT * FROM kg_entities WHERE id = ?", (entity_id,)).fetchone()
    elif name:
        row = cur.execute(
            "SELECT * FROM kg_entities WHERE name = ? COLLATE NOCASE", (name,)
        ).fetchone()
    else:
        return {"success": False, "error": "id or name required"}

    if not row:
        return {"success": False, "error": "Entity not found"}

    entity = _row_to_dict(row)
    eid = row["id"]

    # Get all relationships where this entity is source or target
    rels = cur.execute("""
        SELECT r.*,
               s.name AS source_name, s.type AS source_type,
               t.name AS target_name, t.type AS target_type
        FROM kg_relations r
        JOIN kg_entities s ON r.source_id = s.id
        JOIN kg_entities t ON r.target_id = t.id
        WHERE r.source_id = ? OR r.target_id = ?
        ORDER BY r.strength DESC
    """, (eid, eid)).fetchall()

    relationships = []
    for r in rels:
        rel = _row_to_dict(r)
        # Add resolved direction relative to queried entity
        if r["source_id"] == eid:
            rel["direction"] = "outgoing"
            rel["other_name"] = r["target_name"]
            rel["other_type"] = r["target_type"]
            rel["other_id"] = r["target_id"]
        else:
            rel["direction"] = "incoming"
            rel["other_name"] = r["source_name"]
            rel["other_type"] = r["source_type"]
            rel["other_id"] = r["source_id"]
        relationships.append(rel)

    entity["relationships"] = relationships
    return {"success": True, "entity": entity}


def cmd_stats(args, cur):
    """Counts by type, most connected, most stale."""
    # Counts by type
    type_counts = {}
    for row in cur.execute(
        "SELECT type, COUNT(*) as cnt FROM kg_entities GROUP BY type ORDER BY cnt DESC"
    ):
        type_counts[row["type"]] = row["cnt"]

    # Most connected (top 10)
    most_connected = []
    for row in cur.execute("""
        SELECT e.id, e.name, e.type,
               (SELECT COUNT(*) FROM kg_relations r
                WHERE r.source_id = e.id OR r.target_id = e.id) AS rel_count
        FROM kg_entities e
        ORDER BY rel_count DESC LIMIT 10
    """):
        most_connected.append({
            "id": row["id"], "name": row["name"],
            "type": row["type"], "rel_count": row["rel_count"]
        })

    # Most stale (top 10 by last_mentioned, oldest first)
    most_stale = []
    for row in cur.execute("""
        SELECT id, name, type, last_mentioned
        FROM kg_entities ORDER BY last_mentioned ASC LIMIT 10
    """):
        most_stale.append(_row_to_dict(row))

    total = cur.execute("SELECT COUNT(*) as cnt FROM kg_entities").fetchone()["cnt"]
    rel_total = cur.execute("SELECT COUNT(*) as cnt FROM kg_relations").fetchone()["cnt"]

    return {
        "success": True,
        "total_entities": total,
        "total_relations": rel_total,
        "by_type": type_counts,
        "most_connected": most_connected,
        "most_stale": most_stale,
    }


def cmd_stale(args, cur):
    """Entities not mentioned in N days, optionally filtered by type."""
    days = args.get("days", 14)
    etype = args.get("type")

    conditions = ["e.last_mentioned < datetime('now', ?)", ]
    params = [f"-{days} days"]

    if etype:
        conditions.append("e.type = ?")
        params.append(etype)

    where = " WHERE " + " AND ".join(conditions)

    rows = cur.execute(f"""
        SELECT e.id, e.name, e.type, e.confidence, e.mention_count,
               e.last_mentioned, e.notes,
               (SELECT COUNT(*) FROM kg_relations r
                WHERE r.source_id = e.id OR r.target_id = e.id) AS rel_count
        FROM kg_entities e{where}
        ORDER BY e.last_mentioned ASC
    """, params).fetchall()

    entities = [_row_to_dict(r) for r in rows]
    return {"success": True, "entities": entities, "count": len(entities), "days": days}


def cmd_neighbors(args, cur):
    """Entities within N hops, optionally filtered by type or place."""
    entity_id = args.get("id")
    name = args.get("name")
    hops = args.get("hops", 1)
    filter_type = args.get("filter_type")

    # Resolve starting entity
    if entity_id:
        start_id = entity_id
    elif name:
        row = cur.execute(
            "SELECT id FROM kg_entities WHERE name = ? COLLATE NOCASE", (name,)
        ).fetchone()
        if not row:
            return {"success": False, "error": f"Entity not found: {name}"}
        start_id = row["id"]
    else:
        return {"success": False, "error": "id or name required"}

    # BFS traversal
    visited = {start_id}
    frontier = {start_id}
    all_rels = []

    for _hop in range(hops):
        if not frontier:
            break
        placeholders = ",".join("?" * len(frontier))
        rows = cur.execute(f"""
            SELECT r.*, s.name AS source_name, t.name AS target_name
            FROM kg_relations r
            JOIN kg_entities s ON r.source_id = s.id
            JOIN kg_entities t ON r.target_id = t.id
            WHERE r.source_id IN ({placeholders}) OR r.target_id IN ({placeholders})
        """, list(frontier) + list(frontier)).fetchall()

        next_frontier = set()
        for r in rows:
            all_rels.append(_row_to_dict(r))
            for eid in (r["source_id"], r["target_id"]):
                if eid not in visited:
                    next_frontier.add(eid)
                    visited.add(eid)
        frontier = next_frontier

    # Fetch all discovered entities
    visited.discard(start_id)
    if not visited:
        return {"success": True, "neighbors": [], "relations": []}

    placeholders = ",".join("?" * len(visited))
    query = f"SELECT * FROM kg_entities WHERE id IN ({placeholders})"
    params = list(visited)

    if filter_type:
        query = f"SELECT * FROM kg_entities WHERE id IN ({placeholders}) AND type = ?"
        params.append(filter_type)

    neighbors = [_row_to_dict(r) for r in cur.execute(query, params).fetchall()]

    return {"success": True, "neighbors": neighbors, "relations": all_rels}


def cmd_delete_entity(args, cur):
    """Delete an entity and its relationships (CASCADE)."""
    entity_id = args.get("id")
    name = args.get("name")

    if entity_id:
        row = cur.execute("SELECT * FROM kg_entities WHERE id = ?", (entity_id,)).fetchone()
    elif name:
        row = cur.execute(
            "SELECT * FROM kg_entities WHERE name = ? COLLATE NOCASE", (name,)
        ).fetchone()
    else:
        return {"success": False, "error": "id or name required"}

    if not row:
        return {"success": False, "error": "Entity not found"}

    cur.execute("DELETE FROM kg_entities WHERE id = ?", (row["id"],))
    cur.execute(
        "INSERT INTO kg_changelog (ts, action, entity_id, detail) VALUES (?, ?, ?, ?)",
        (utcnow(), "entity_deleted", row["id"], f"{row['type']}: {row['name']}")
    )

    return {"success": True, "deleted": row["name"]}


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _resolve_entity(cur, ref):
    """Resolve an entity reference (int ID or string name) to an ID."""
    if isinstance(ref, int):
        return ref
    if isinstance(ref, str) and ref.isdigit():
        return int(ref)
    row = cur.execute(
        "SELECT id FROM kg_entities WHERE name = ? COLLATE NOCASE", (ref,)
    ).fetchone()
    return row["id"] if row else None


def _row_to_dict(row):
    """Convert a sqlite3.Row to a plain dict, parsing JSON metadata."""
    d = dict(row)
    if "metadata" in d and isinstance(d["metadata"], str):
        try:
            d["metadata"] = json.loads(d["metadata"])
        except (json.JSONDecodeError, TypeError):
            pass
    return d


# ─── Dispatch ────────────────────────────────────────────────────────────────

COMMANDS = {
    "init": cmd_init,
    "upsert_entity": cmd_upsert_entity,
    "upsert_relation": cmd_upsert_relation,
    "query": cmd_query,
    "get": cmd_get,
    "stats": cmd_stats,
    "stale": cmd_stale,
    "neighbors": cmd_neighbors,
    "delete_entity": cmd_delete_entity,
}


def main():
    try:
        input_data = json.loads(sys.stdin.read())
    except json.JSONDecodeError:
        log_event("error", "Invalid JSON input")
        print(json.dumps({"error": "Invalid JSON input", "success": False}))
        return

    command = input_data.get("command", "")
    args = input_data.get("args", {})

    log_event("info", f"Executing command", command)

    handler = COMMANDS.get(command)
    if not handler:
        print(json.dumps({"error": f"Unknown command: {command}", "success": False}))
        return

    try:
        with get_cursor() as cur:
            result = handler(args, cur)
        print(json.dumps(result, default=str))
    except Exception as e:
        log_event("error", str(e), command)
        print(json.dumps({"error": str(e), "success": False}))


if __name__ == "__main__":
    main()
