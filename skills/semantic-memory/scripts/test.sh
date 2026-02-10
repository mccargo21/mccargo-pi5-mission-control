#!/bin/bash
# Test semantic memory integration

set -euo pipefail

WORKSPACE="/home/mccargo/.openclaw/workspace"
SM_DIR="$WORKSPACE/skills/semantic-memory"

echo "========================================"
echo "🧠 Semantic Memory Tests"
echo "========================================"
echo ""

PASSED=0
FAILED=0

test_pass() {
    echo "✅ $1"
    ((PASSED++)) || true
}

test_fail() {
    echo "❌ $1"
    ((FAILED++)) || true
}

# Test 1: Store memory
echo "Test 1: Store memory..."
RESULT=$(bash "$SM_DIR/scripts/sm.sh" store "Test: Discussed pricing strategy" test-session 2>/dev/null)
if echo "$RESULT" | grep -q '"success": true'; then
    test_pass "Store memory works"
else
    test_fail "Store memory failed"
fi

# Test 2: Search memory
echo "Test 2: Search memory..."
RESULT=$(bash "$SM_DIR/scripts/sm.sh" search "pricing" 2>/dev/null)
if echo "$RESULT" | grep -q '"success": true'; then
    test_pass "Search memory works"
else
    test_fail "Search memory failed"
fi

# Test 3: Get stats
echo "Test 3: Get stats..."
RESULT=$(bash "$SM_DIR/scripts/sm.sh" stats 2>/dev/null)
if echo "$RESULT" | grep -q '"total_memories"'; then
    test_pass "Stats retrieval works"
else
    test_fail "Stats retrieval failed"
fi

# Test 4: Python import
echo "Test 4: Python import..."
if python3 -c "
import sys
sys.path.insert(0, '$SM_DIR/scripts')
from semantic_memory import SemanticMemory, remember, recall
print('IMPORT_OK')
" 2>/dev/null | grep -q "IMPORT_OK"; then
    test_pass "Python import works"
else
    test_fail "Python import failed"
fi

# Test 5: Direct Python usage
echo "Test 5: Direct Python usage..."
RESULT=$(python3 -c "
import sys
sys.path.insert(0, '$SM_DIR/scripts')
from semantic_memory import SemanticMemory

memory = SemanticMemory()
id = memory.store('Test memory from Python', session_id='py-test')
results = memory.search('Python test', k=1)
print(f'FOUND:{len(results)}')
" 2>/dev/null)
if echo "$RESULT" | grep -q "FOUND:1"; then
    test_pass "Direct Python usage works"
else
    test_fail "Direct Python usage failed"
fi

echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
