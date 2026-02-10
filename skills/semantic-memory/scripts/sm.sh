#!/bin/bash
# Semantic Memory Bridge
# Bash wrapper for semantic memory operations
#
# Usage:
#   sm.sh store "text to remember" [session_id] [metadata_json]
#   sm.sh search "query" [k=5]
#   sm.sh recent [n=10]
#   sm.sh stats

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/semantic_memory.py"

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    store)
        TEXT="${1:-}"
        SESSION_ID="${2:-}"
        METADATA="${3:-{}}"
        
        if [ -z "$TEXT" ]; then
            echo '{"error": "No text provided"}'
            exit 1
        fi
        
        python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from semantic_memory import remember
import json

result = remember('$TEXT', session_id='$SESSION_ID' if '$SESSION_ID' else None, 
                  metadata=json.loads('$METADATA'))
print(json.dumps({'success': True, 'id': result}))
"
        ;;
        
    search)
        QUERY="${1:-}"
        K="${2:-5}"
        
        if [ -z "$QUERY" ]; then
            echo '{"error": "No query provided"}'
            exit 1
        fi
        
        python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from semantic_memory import recall
import json

results = recall('$QUERY', k=$K)
print(json.dumps({'success': True, 'results': results}))
"
        ;;
        
    recent)
        N="${1:-10}"
        
        python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from semantic_memory import SemanticMemory
import json

memory = SemanticMemory()
results = memory.get_recent(n=$N)
print(json.dumps({'success': True, 'results': results}))
"
        ;;
        
    stats)
        python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from semantic_memory import SemanticMemory
import json

memory = SemanticMemory()
print(json.dumps(memory.stats(), indent=2))
"
        ;;
        
    session)
        SESSION_ID="${1:-}"
        
        if [ -z "$SESSION_ID" ]; then
            echo '{"error": "No session_id provided"}'
            exit 1
        fi
        
        python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR')
from semantic_memory import SemanticMemory
import json

memory = SemanticMemory()
results = memory.get_by_session('$SESSION_ID')
print(json.dumps({'success': True, 'results': results}))
"
        ;;
        
    *)
        echo "Semantic Memory Bridge"
        echo ""
        echo "Usage:"
        echo "  sm.sh store \"text\" [session_id] [metadata]  - Store a memory"
        echo "  sm.sh search \"query\" [k]                    - Search memories"
        echo "  sm.sh recent [n]                              - Get recent memories"
        echo "  sm.sh stats                                   - Show statistics"
        echo "  sm.sh session <session_id>                    - Get session memories"
        echo ""
        echo "Examples:"
        echo "  sm.sh store \"Discussed pricing strategy\" session-123"
        echo "  sm.sh search \"pricing\" 3"
        echo "  sm.sh stats"
        exit 1
        ;;
esac
