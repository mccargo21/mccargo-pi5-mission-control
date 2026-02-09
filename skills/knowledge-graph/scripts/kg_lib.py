#!/usr/bin/env python3
"""
Knowledge Graph — Shared DB connection helpers.

Provides a consistent interface for accessing the KG SQLite database.
All scripts import from here to ensure a single source of truth for paths and connections.
"""

import os
import sqlite3
import json
from pathlib import Path
from datetime import datetime, timezone
from contextlib import contextmanager

# Database location — separate from main.sqlite to avoid upgrade conflicts
KG_DIR = Path(__file__).parent.parent / "data"
KG_DB = KG_DIR / "kg.sqlite"

# Central logging
LOG_FILE = Path(os.environ.get(
    "OPENCLAW_LOG_FILE",
    os.path.expanduser("~/.openclaw/workspace/logs/openclaw-events.jsonl"),
))


def log_event(level: str, message: str, command: str = ""):
    """Append a structured JSON log line to the central log."""
    try:
        LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
        entry = json.dumps({
            "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "level": level,
            "script": "kg-bridge",
            "command": command,
            "msg": message,
        })
        with open(LOG_FILE, "a") as f:
            f.write(entry + "\n")
    except Exception:
        pass  # Never let logging break the bridge


def utcnow() -> str:
    """Return current UTC timestamp in ISO format."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def get_connection() -> sqlite3.Connection:
    """Open a connection to the KG database with standard pragmas."""
    KG_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(KG_DB))
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


@contextmanager
def get_cursor():
    """Context manager yielding a cursor with auto-commit/rollback."""
    conn = get_connection()
    try:
        cur = conn.cursor()
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
