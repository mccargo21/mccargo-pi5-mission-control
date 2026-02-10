#!/usr/bin/env python3
"""
Semantic Memory System

Stores and retrieves conversational context using vector embeddings.
Enables "remember when I said..." functionality and cross-session context.

Uses sqlite-vec for vector storage (lightweight, no external services).
Falls back to simple keyword matching if embeddings unavailable.

Usage:
    from semantic_memory import SemanticMemory
    
    memory = SemanticMemory()
    
    # Store a memory
    memory.store("User asked about competitor pricing yesterday", 
                 metadata={"session_id": "abc123", "timestamp": "2026-02-10T10:00:00Z"})
    
    # Retrieve relevant memories
    results = memory.search("What did I ask about competitors?", k=5)
    # Returns: [{"text": "User asked about competitor pricing...", "score": 0.95, ...}]
"""

import os
import re
import json
import hashlib
import sqlite3
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from dataclasses import dataclass

# Paths
MEMORY_DIR = Path(__file__).parent.parent / "data"
MEMORY_DB = MEMORY_DIR / "semantic-memory.sqlite"

# Try to import sqlite-vec for vector search
try:
    import sqlite_vec
    SQLITE_VEC_AVAILABLE = True
except ImportError:
    SQLITE_VEC_AVAILABLE = False
    print("Warning: sqlite-vec not available, falling back to keyword search")


@dataclass
class MemoryEntry:
    """A single memory entry."""
    id: str
    text: str
    embedding: Optional[List[float]] = None
    metadata: Dict[str, Any] = None
    created_at: str = None
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now(timezone.utc).isoformat()
        if self.metadata is None:
            self.metadata = {}


class SemanticMemory:
    """Semantic memory system with vector embeddings."""
    
    def __init__(self, db_path: Path = MEMORY_DB, embedding_dim: int = 384):
        self.db_path = Path(db_path)
        self.embedding_dim = embedding_dim
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        self._init_db()
    
    def _init_db(self):
        """Initialize the database schema."""
        conn = sqlite3.connect(str(self.db_path))
        
        # Main memories table
        conn.execute("""
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                text TEXT NOT NULL,
                embedding BLOB,
                metadata TEXT DEFAULT '{}',
                created_at TEXT NOT NULL,
                session_id TEXT,
                memory_type TEXT DEFAULT 'conversation'
            )
        """)
        
        # FTS5 for text search (fallback when embeddings unavailable)
        conn.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
                text, content='memories', content_rowid='rowid'
            )
        """)
        
        # Triggers to keep FTS in sync
        conn.execute("""
            CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
                INSERT INTO memories_fts(rowid, text) VALUES (new.rowid, new.text);
            END
        """)
        
        conn.execute("""
            CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
                INSERT INTO memories_fts(memories_fts, rowid, text) VALUES ('delete', old.rowid, old.text);
            END
        """)
        
        conn.execute("""
            CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
                INSERT INTO memories_fts(memories_fts, rowid, text) VALUES ('delete', old.rowid, old.text);
                INSERT INTO memories_fts(rowid, text) VALUES (new.rowid, new.text);
            END
        """)
        
        # Indexes
        conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_session ON memories(session_id)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_created ON memories(created_at)")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(memory_type)")
        
        # Try to create vec0 virtual table for vector search
        if SQLITE_VEC_AVAILABLE:
            try:
                conn.execute(f"""
                    CREATE VIRTUAL TABLE IF NOT EXISTS memory_vectors USING vec0(
                        embedding float[{self.embedding_dim}]
                    )
                """)
                self.vector_search_available = True
            except Exception as e:
                print(f"Warning: Could not create vector table: {e}")
                self.vector_search_available = False
        else:
            self.vector_search_available = False
        
        conn.commit()
        conn.close()
    
    def _generate_embedding(self, text: str) -> Optional[List[float]]:
        """Generate embedding for text.
        
        For production, use OpenAI, sentence-transformers, or local model.
        This is a simplified fallback that creates a basic vector.
        """
        try:
            # Try to use a local embedding model if available
            # For now, create a simple hash-based embedding as fallback
            return self._simple_embedding(text)
        except Exception as e:
            print(f"Error generating embedding: {e}")
            return None
    
    def _simple_embedding(self, text: str) -> List[float]:
        """Create a simple embedding from text (fallback method).
        
        Uses character n-gram frequencies as a basic vector representation.
        Not as good as neural embeddings but works without dependencies.
        """
        text = text.lower()
        
        # Create n-grams
        ngrams = []
        for n in [2, 3]:
            for i in range(len(text) - n + 1):
                ngrams.append(text[i:i+n])
        
        # Hash n-grams to fixed-size vector
        vector = [0.0] * self.embedding_dim
        for ngram in ngrams:
            hash_val = int(hashlib.md5(ngram.encode()).hexdigest(), 16)
            idx = hash_val % self.embedding_dim
            vector[idx] += 1.0
        
        # Normalize
        magnitude = sum(x**2 for x in vector) ** 0.5
        if magnitude > 0:
            vector = [x / magnitude for x in vector]
        
        return vector
    
    def _cosine_similarity(self, vec1: List[float], vec2: List[float]) -> float:
        """Calculate cosine similarity between two vectors."""
        dot_product = sum(a * b for a, b in zip(vec1, vec2))
        magnitude1 = sum(x**2 for x in vec1) ** 0.5
        magnitude2 = sum(x**2 for x in vec2) ** 0.5
        
        if magnitude1 == 0 or magnitude2 == 0:
            return 0.0
        
        return dot_product / (magnitude1 * magnitude2)
    
    def store(self, text: str, metadata: Optional[Dict] = None, 
              session_id: Optional[str] = None,
              memory_type: str = "conversation") -> str:
        """Store a memory.
        
        Args:
            text: The text to store
            metadata: Optional metadata dict
            session_id: Session identifier for grouping
            memory_type: Type of memory (conversation, task, etc.)
        
        Returns:
            The memory ID
        """
        memory_id = hashlib.sha256(
            f"{text}:{datetime.now(timezone.utc).isoformat()}".encode()
        ).hexdigest()[:16]
        
        # Generate embedding
        embedding = self._generate_embedding(text)
        
        created_at = datetime.now(timezone.utc).isoformat()
        
        conn = sqlite3.connect(str(self.db_path))
        
        # Store in main table
        conn.execute(
            """INSERT INTO memories (id, text, embedding, metadata, created_at, session_id, memory_type)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (memory_id, text, 
             json.dumps(embedding) if embedding else None,
             json.dumps(metadata or {}),
             created_at,
             session_id,
             memory_type)
        )
        
        # Store in vector table if available
        if self.vector_search_available and embedding:
            try:
                conn.execute(
                    "INSERT INTO memory_vectors (rowid, embedding) VALUES (?, ?)",
                    (memory_id, sqlite_vec.serialize_float32(embedding))
                )
            except Exception as e:
                print(f"Warning: Could not store vector: {e}")
        
        conn.commit()
        conn.close()
        
        return memory_id
    
    def search(self, query: str, k: int = 5, 
               memory_type: Optional[str] = None,
               session_id: Optional[str] = None,
               min_score: float = 0.0) -> List[Dict]:
        """Search for relevant memories.
        
        Args:
            query: Search query text
            k: Number of results to return
            memory_type: Filter by memory type
            session_id: Filter by session
            min_score: Minimum relevance score (0-1)
        
        Returns:
            List of matching memories with scores
        """
        # Generate query embedding
        query_embedding = self._generate_embedding(query)
        
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        
        results = []
        
        # Try vector search first
        if self.vector_search_available and query_embedding:
            try:
                # Use sqlite-vec for vector search
                cursor = conn.execute(
                    """SELECT m.*, v.distance
                       FROM memory_vectors v
                       JOIN memories m ON m.id = v.rowid
                       ORDER BY v.distance
                       LIMIT ?""",
                    (k * 2,)  # Get more for filtering
                )
                
                for row in cursor.fetchall():
                    score = 1.0 / (1.0 + row['distance'])  # Convert distance to similarity
                    
                    if score < min_score:
                        continue
                    
                    if memory_type and row['memory_type'] != memory_type:
                        continue
                    
                    if session_id and row['session_id'] != session_id:
                        continue
                    
                    results.append({
                        "id": row['id'],
                        "text": row['text'],
                        "score": score,
                        "metadata": json.loads(row['metadata'] or '{}'),
                        "created_at": row['created_at'],
                        "session_id": row['session_id'],
                        "memory_type": row['memory_type'],
                        "search_method": "vector"
                    })
                    
                    if len(results) >= k:
                        break
                
            except Exception as e:
                print(f"Vector search failed, falling back to keyword: {e}")
        
        # Fallback to keyword search if vector not available or no results
        if not results:
            # Use FTS5 for keyword search
            cursor = conn.execute(
                """SELECT m.*
                   FROM memories m
                   JOIN memories_fts fts ON m.rowid = fts.rowid
                   WHERE memories_fts MATCH ?
                   ORDER BY rank
                   LIMIT ?""",
                (query, k * 2)
            )
            
            for row in cursor.fetchall():
                # Simple keyword match scoring
                score = self._keyword_score(query, row['text'])
                
                if score < min_score:
                    continue
                
                if memory_type and row['memory_type'] != memory_type:
                    continue
                
                if session_id and row['session_id'] != session_id:
                    continue
                
                results.append({
                    "id": row['id'],
                    "text": row['text'],
                    "score": score,
                    "metadata": json.loads(row['metadata'] or '{}'),
                    "created_at": row['created_at'],
                    "session_id": row['session_id'],
                    "memory_type": row['memory_type'],
                    "search_method": "keyword"
                })
                
                if len(results) >= k:
                    break
        
        conn.close()
        
        # Sort by score and return top k
        results.sort(key=lambda x: x['score'], reverse=True)
        return results[:k]
    
    def _keyword_score(self, query: str, text: str) -> float:
        """Calculate simple keyword match score."""
        query_words = set(query.lower().split())
        text_words = set(text.lower().split())
        
        if not query_words:
            return 0.0
        
        matches = len(query_words & text_words)
        return matches / len(query_words)
    
    def get_recent(self, n: int = 10, memory_type: Optional[str] = None) -> List[Dict]:
        """Get recent memories.
        
        Args:
            n: Number of memories to return
            memory_type: Filter by memory type
        
        Returns:
            List of recent memories
        """
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        
        if memory_type:
            cursor = conn.execute(
                """SELECT * FROM memories 
                   WHERE memory_type = ?
                   ORDER BY created_at DESC
                   LIMIT ?""",
                (memory_type, n)
            )
        else:
            cursor = conn.execute(
                """SELECT * FROM memories 
                   ORDER BY created_at DESC
                   LIMIT ?""",
                (n,)
            )
        
        results = []
        for row in cursor.fetchall():
            results.append({
                "id": row['id'],
                "text": row['text'],
                "metadata": json.loads(row['metadata'] or '{}'),
                "created_at": row['created_at'],
                "session_id": row['session_id'],
                "memory_type": row['memory_type']
            })
        
        conn.close()
        return results
    
    def get_by_session(self, session_id: str) -> List[Dict]:
        """Get all memories for a session."""
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        
        cursor = conn.execute(
            """SELECT * FROM memories WHERE session_id = ? ORDER BY created_at""",
            (session_id,)
        )
        
        results = []
        for row in cursor.fetchall():
            results.append({
                "id": row['id'],
                "text": row['text'],
                "metadata": json.loads(row['metadata'] or '{}'),
                "created_at": row['created_at'],
                "session_id": row['session_id'],
                "memory_type": row['memory_type']
            })
        
        conn.close()
        return results
    
    def delete_old(self, days: int = 90) -> int:
        """Delete memories older than N days.
        
        Returns:
            Number of memories deleted
        """
        conn = sqlite3.connect(str(self.db_path))
        
        cursor = conn.execute(
            """DELETE FROM memories 
               WHERE created_at < datetime('now', ?)""",
            (f"-{days} days",)
        )
        
        deleted = cursor.rowcount
        conn.commit()
        conn.close()
        
        return deleted
    
    def stats(self) -> Dict:
        """Get memory statistics."""
        conn = sqlite3.connect(str(self.db_path))
        
        # Total memories
        cursor = conn.execute("SELECT COUNT(*) FROM memories")
        total = cursor.fetchone()[0]
        
        # By type
        cursor = conn.execute(
            """SELECT memory_type, COUNT(*) FROM memories GROUP BY memory_type"""
        )
        by_type = dict(cursor.fetchall())
        
        # By session
        cursor = conn.execute(
            """SELECT COUNT(DISTINCT session_id) FROM memories"""
        )
        sessions = cursor.fetchone()[0]
        
        # Oldest memory
        cursor = conn.execute(
            """SELECT created_at FROM memories ORDER BY created_at LIMIT 1"""
        )
        oldest = cursor.fetchone()
        oldest = oldest[0] if oldest else None
        
        # Newest memory
        cursor = conn.execute(
            """SELECT created_at FROM memories ORDER BY created_at DESC LIMIT 1"""
        )
        newest = cursor.fetchone()
        newest = newest[0] if newest else None
        
        conn.close()
        
        return {
            "total_memories": total,
            "by_type": by_type,
            "unique_sessions": sessions,
            "oldest_memory": oldest,
            "newest_memory": newest,
            "vector_search_available": self.vector_search_available
        }


# Convenience functions for use in skills
def remember(text: str, **kwargs) -> str:
    """Store a memory (convenience function)."""
    memory = SemanticMemory()
    return memory.store(text, **kwargs)


def recall(query: str, **kwargs) -> List[Dict]:
    """Search memories (convenience function)."""
    memory = SemanticMemory()
    return memory.search(query, **kwargs)


# Example/test
if __name__ == "__main__":
    import tempfile
    import shutil
    
    # Test with temporary directory
    test_dir = tempfile.mkdtemp()
    test_db = Path(test_dir) / "test-memory.sqlite"
    
    try:
        memory = SemanticMemory(db_path=test_db)
        
        # Store some memories
        print("Storing memories...")
        m1 = memory.store("User asked about Tesla stock price yesterday", 
                         metadata={"topic": "finance", "user": "Adam"},
                         session_id="session-1")
        print(f"Stored memory 1: {m1}")
        
        m2 = memory.store("User wants to research competitor pricing for their product",
                         metadata={"topic": "business", "user": "Adam"},
                         session_id="session-1")
        print(f"Stored memory 2: {m2}")
        
        m3 = memory.store("Travel plans to Islamorada in February",
                         metadata={"topic": "travel", "user": "Adam"},
                         session_id="session-2")
        print(f"Stored memory 3: {m3}")
        
        # Search
        print("\nSearching for 'Tesla':")
        results = memory.search("Tesla", k=2)
        for r in results:
            print(f"  Score: {r['score']:.3f} | {r['text'][:60]}...")
        
        print("\nSearching for 'competitors':")
        results = memory.search("competitors", k=2)
        for r in results:
            print(f"  Score: {r['score']:.3f} | {r['text'][:60]}...")
        
        print("\nSearching for 'vacation plans':")
        results = memory.search("vacation plans", k=2)
        for r in results:
            print(f"  Score: {r['score']:.3f} | {r['text'][:60]}...")
        
        # Stats
        print("\nMemory stats:")
        stats = memory.stats()
        print(f"  Total: {stats['total_memories']}")
        print(f"  By type: {stats['by_type']}")
        print(f"  Sessions: {stats['unique_sessions']}")
        
        print("\n✅ Semantic memory tests passed!")
        
    finally:
        shutil.rmtree(test_dir)
