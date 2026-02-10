#!/usr/bin/env python3
"""
Knowledge Graph — Shared DB connection helpers with connection pooling.

Provides a consistent interface for accessing the KG SQLite database.
All scripts import from here to ensure a single source of truth for paths and connections.

Enhancement: Added connection pooling for high-frequency operations.
"""

import os
import sqlite3
import json
from pathlib import Path
from datetime import datetime, timezone
from contextlib import contextmanager
from functools import lru_cache
from typing import Optional

# Database location — separate from main.sqlite to avoid upgrade conflicts
KG_DIR = Path(__file__).parent.parent / "data"
KG_DB = KG_DIR / "kg.sqlite"

# Central logging
LOG_FILE = Path(os.environ.get(
    "OPENCLAW_LOG_FILE",
    os.path.expanduser("~/.openclaw/workspace/logs/openclaw-events.jsonl"),
))

# Connection pool settings
MAX_POOL_SIZE = 5
_connection_pool: list[sqlite3.Connection] = []
_pool_in_use: set[sqlite3.Connection] = set()


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


def _create_connection() -> sqlite3.Connection:
    """Create a new database connection with standard pragmas."""
    KG_DIR.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(KG_DB), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.execute("PRAGMA synchronous=NORMAL")  # Performance: don't wait for full fsync
    return conn


def get_connection() -> sqlite3.Connection:
    """Open a connection to the KG database with standard pragmas.
    
    For one-off operations. For high-frequency operations, use get_pooled_connection().
    """
    return _create_connection()


@lru_cache(maxsize=1)
def get_cached_connection() -> sqlite3.Connection:
    """Get a cached connection for repeated use within the same process.
    
    WARNING: This connection is cached for the lifetime of the process.
    Only use for short-lived operations or single-threaded contexts.
    The connection will be closed when the process exits.
    """
    return _create_connection()


def get_pooled_connection() -> sqlite3.Connection:
    """Get a connection from the pool, or create a new one if pool is empty.
    
    Use this for high-frequency operations to avoid connection overhead.
    Return connections to the pool with release_connection().
    """
    global _connection_pool, _pool_in_use
    
    # Try to reuse an available connection
    while _connection_pool:
        conn = _connection_pool.pop()
        try:
            # Verify connection is still alive
            conn.execute("SELECT 1")
            _pool_in_use.add(conn)
            return conn
        except sqlite3.Error:
            # Connection is dead, close it and try next
            try:
                conn.close()
            except:
                pass
            continue
    
    # Pool is empty or all connections dead - create new
    conn = _create_connection()
    _pool_in_use.add(conn)
    return conn


def release_connection(conn: sqlite3.Connection) -> None:
    """Return a connection to the pool for reuse."""
    global _connection_pool, _pool_in_use
    
    if conn in _pool_in_use:
        _pool_in_use.discard(conn)
        
        # Only keep up to MAX_POOL_SIZE connections
        if len(_connection_pool) < MAX_POOL_SIZE:
            try:
                # Verify connection is still good before returning to pool
                conn.execute("SELECT 1")
                _connection_pool.append(conn)
                return
            except sqlite3.Error:
                pass  # Connection is dead, don't return to pool
        
        # Close connection if pool is full or connection is dead
        try:
            conn.close()
        except:
            pass


def close_all_connections() -> None:
    """Close all pooled and in-use connections. Use on process shutdown."""
    global _connection_pool, _pool_in_use
    
    for conn in list(_pool_in_use) | set(_connection_pool):
        try:
            conn.close()
        except:
            pass
    
    _pool_in_use.clear()
    _connection_pool.clear()
    get_cached_connection.cache_clear()


@contextmanager
def get_cursor():
    """Context manager yielding a cursor with auto-commit/rollback.
    
    Uses a fresh connection each time. For high-frequency operations,
    consider using get_pooled_cursor() instead.
    """
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


@contextmanager
def get_pooled_cursor():
    """Context manager yielding a cursor using connection pooling.
    
    More efficient for high-frequency operations. Connection is returned
    to the pool after use.
    """
    conn = get_pooled_connection()
    try:
        cur = conn.cursor()
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        release_connection(conn)


# Performance monitoring
def get_pool_stats() -> dict:
    """Get current connection pool statistics."""
    return {
        "pool_size": len(_connection_pool),
        "in_use": len(_pool_in_use),
        "max_size": MAX_POOL_SIZE,
        "cached_connection_active": get_cached_connection.cache_info().currsize,
    }
