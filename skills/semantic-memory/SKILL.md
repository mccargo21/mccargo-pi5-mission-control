# Semantic Memory

Stores and retrieves conversational context using vector embeddings. Enables "remember when I said..." functionality and cross-session context awareness.

## Overview

This skill provides long-term memory for your OpenClaw assistant. It stores conversations, tasks, and important information with semantic search capabilities, allowing the system to recall relevant context from previous sessions.

**Key Features:**
- Vector-based semantic search (falls back to keyword search)
- Session-based memory organization
- Metadata tagging for filtering
- Automatic memory pruning (configurable retention)
- Cross-session context retrieval

## Installation

No external dependencies required. Uses SQLite with optional sqlite-vec for vector search.

To enable full vector search:
```bash
pip install sqlite-vec
```

## Usage

### From Python

```python
from semantic_memory import SemanticMemory, remember, recall

# Method 1: Direct class usage
memory = SemanticMemory()

# Store a memory
memory_id = memory.store(
    "User asked about competitor pricing strategy",
    metadata={"topic": "business", "priority": "high"},
    session_id="session-abc123",
    memory_type="conversation"
)

# Search for relevant memories
results = memory.search("What did I ask about competitors?", k=5)
for result in results:
    print(f"Score: {result['score']:.2f}")
    print(f"Text: {result['text']}")
    print(f"When: {result['created_at']}")

# Get recent memories
recent = memory.get_recent(n=10)

# Get all memories from a session
session_memories = memory.get_by_session("session-abc123")

# Get statistics
stats = memory.stats()
print(f"Total memories: {stats['total_memories']}")

# Method 2: Convenience functions
remember("Important conversation detail", session_id="current")
results = recall("pricing strategy", k=3)
```

### From Bash

```bash
# Store a memory
./scripts/sm.sh store "Discussed Q1 budget planning" session-123

# Search memories
./scripts/sm.sh search "budget planning"

# Get recent memories
./scripts/sm.sh recent 5

# Get session memories
./scripts/sm.sh session session-123

# Show statistics
./scripts/sm.sh stats
```

## How It Works

### Storage
1. Text is stored in SQLite with metadata
2. Embedding vector generated (384 dimensions)
3. Full-text search index created for keyword fallback
4. Vector stored in vec0 virtual table (if sqlite-vec available)

### Retrieval
1. Query converted to embedding vector
2. Vector similarity search (cosine similarity)
3. Fallback to FTS5 keyword search if needed
4. Results ranked by relevance score
5. Filters applied (session, type, date)

### Search Methods

**Vector Search** (primary):
- Uses embedding similarity
- Finds semantically related content
- Requires: `pip install sqlite-vec`

**Keyword Search** (fallback):
- Uses FTS5 full-text search
- Exact/partial word matching
- Always available

## Data Structure

### Memory Entry
```json
{
  "id": "unique-hash",
  "text": "The actual memory content",
  "embedding": [0.1, 0.2, ...],  // 384-dim vector
  "metadata": {
    "topic": "business",
    "priority": "high"
  },
  "created_at": "2026-02-10T10:00:00Z",
  "session_id": "session-abc123",
  "memory_type": "conversation"
}
```

### Memory Types
- `conversation` - General conversations (default)
- `task` - Task-related information
- `decision` - Important decisions made
- `contact` - Contact information/updates
- `event` - Calendar/event information

## Configuration

Environment variables:
```bash
export SEMANTIC_MEMORY_DB="/path/to/custom/memory.sqlite"
export SEMANTIC_MEMORY_DIM=384  # Embedding dimensions
```

## Integration Examples

### With Proactive Intelligence
```python
from semantic_memory import remember
from pi_nudge_engine import check_followups

# Store nudge context
for nudge in nudges:
    remember(
        f"Generated nudge: {nudge['message']}",
        session_id=current_session,
        metadata={"nudge_type": nudge['type'], "priority": nudge['priority']}
    )
```

### With Knowledge Graph
```python
from semantic_memory import recall
from kg_bridge import query

# Search semantic memory for context
context = recall(user_query, k=3)

# Use context to inform KG query
results = query({
    "text": user_query,
    "type": infer_type_from_context(context)
})
```

### Session Context Preservation
```python
# At session start
previous_context = recall("recent conversations", k=5)

# During session
remember(user_message, session_id=current_session)
remember(assistant_response, session_id=current_session)

# At session end
summary = generate_summary(current_session)
remember(summary, session_id=current_session, memory_type="summary")
```

## Maintenance

### Pruning Old Memories
```python
from semantic_memory import SemanticMemory

memory = SemanticMemory()
deleted_count = memory.delete_old(days=90)
print(f"Deleted {deleted_count} old memories")
```

### Database Location
Default: `~/.openclaw/workspace/skills/semantic-memory/data/semantic-memory.sqlite`

Backup:
```bash
cp skills/semantic-memory/data/semantic-memory.sqlite backup/
```

## Performance

- **Storage**: ~1KB per memory (text + embedding)
- **Search**: <100ms for 10K memories
- **Vector operations**: Requires sqlite-vec for optimal performance
- **Scaling**: Tested up to 100K memories

## Future Enhancements

- [ ] Integration with sentence-transformers for better embeddings
- [ ] Multi-modal memories (images, documents)
- [ ] Memory importance scoring
- [ ] Automatic memory consolidation
- [ ] Cross-user memory sharing (with permission)

## Troubleshooting

### sqlite-vec not available
Install: `pip install sqlite-vec`
Or use keyword search fallback (still functional)

### Memory not found
- Check session_id filter
- Try broader search terms
- Verify memory was stored successfully

### Slow search
- Consider pruning old memories
- Check if sqlite-vec is installed
- Reduce k parameter for faster results

## API Reference

### SemanticMemory Class

#### Methods

**store(text, metadata=None, session_id=None, memory_type="conversation")**
- Store a new memory
- Returns: memory_id (str)

**search(query, k=5, memory_type=None, session_id=None, min_score=0.0)**
- Search for relevant memories
- Returns: List of memory dicts with scores

**get_recent(n=10, memory_type=None)**
- Get recent memories
- Returns: List of memory dicts

**get_by_session(session_id)**
- Get all memories for a session
- Returns: List of memory dicts

**delete_old(days=90)**
- Delete memories older than N days
- Returns: Number deleted

**stats()**
- Get memory statistics
- Returns: Stats dict

### Convenience Functions

**remember(text, **kwargs)**
- Store a memory (one-liner)

**recall(query, **kwargs)**
- Search memories (one-liner)
