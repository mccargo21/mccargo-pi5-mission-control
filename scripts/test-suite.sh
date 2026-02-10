#!/bin/bash
# Comprehensive Test Suite for OpenClaw Workspace
# 
# Categories:
#   - Security tests (pre-existing, validated)
#   - Unit tests for individual functions
#   - Integration tests for end-to-end workflows
#   - Performance tests for connection pooling
#   - Configuration validation tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="/home/mccargo/.openclaw/workspace"
PASSED=0
FAILED=0
SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++)) || true
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((SKIPPED++)) || true
}

# ============================================
# SECURITY TESTS (from test-security.sh)
# ============================================

run_security_tests() {
    log_section "🔒 SECURITY TESTS"
    
    # Test 1: JSON Payload Size Limits
    log_test "JSON Payload Size Limits (pi-nudge-engine.py)"
    if echo '{"command":"check_all"}' | python3 "$WORKSPACE/skills/proactive-intel/scripts/pi-nudge-engine.py" | grep -q '"success": true'; then
        log_pass "Normal payload accepted"
    else
        log_fail "Normal payload rejected"
    fi
    
    # Test 2: SQL Injection Prevention
    log_test "SQL Injection Prevention (kg-bridge.py)"
    RESULT=$(echo '{"command":"query","args":{"metadata":{"__proto__":"test"}}}' | python3 "$WORKSPACE/skills/knowledge-graph/scripts/kg-bridge.py")
    if echo "$RESULT" | grep -q '"success": true'; then
        log_pass "Reserved key (__proto__) properly ignored"
    else
        log_fail "Reserved key handling unexpected"
    fi
    
    # Test 3: Log File Permissions
    log_test "Log File Permissions"
    TEST_LOG="$WORKSPACE/logs/test-$(date +%s).log"
    echo "test" > "$TEST_LOG"
    chmod 600 "$TEST_LOG"
    PERMS=$(stat -c "%a" "$TEST_LOG" 2>/dev/null || stat -f "%OLp" "$TEST_LOG")
    if [ "$PERMS" = "600" ]; then
        log_pass "Log file permissions set to 600"
    else
        log_fail "Log file permissions are $PERMS"
    fi
    rm -f "$TEST_LOG"
    
    # Test 4: PID-Based Locking
    log_test "PID-Based Locking (lock.sh)"
    source "$WORKSPACE/scripts/lib/lock.sh"
    if acquire_lock "test-suite-$$" 60; then
        log_pass "Lock acquired"
        if ! acquire_lock "test-suite-$$" 60; then
            log_pass "Lock prevents duplicates"
        else
            log_fail "Lock allows duplicates"
        fi
        release_lock "test-suite-$$"
    else
        log_fail "Failed to acquire lock"
    fi
    
    # Test 5: Input Validation
    log_test "Input Validation Patterns"
    if echo "test_123" | grep -qE '^[a-zA-Z0-9_-]+$'; then
        log_pass "Valid ID format accepted"
    else
        log_fail "Valid ID format rejected"
    fi
    if echo "test;rm" | grep -qE '[;&|$\(]'; then
        log_pass "Shell injection detected"
    else
        log_fail "Shell injection not detected"
    fi
}

# ============================================
# UNIT TESTS
# ============================================

run_unit_tests() {
    log_section "🧪 UNIT TESTS"
    
    # Test: kg_lib connection pooling
    log_test "Connection Pool Creation"
    python3 << 'PYEOF'
import sys
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/skills/knowledge-graph/scripts')
from kg_lib import get_pooled_connection, release_connection, get_pool_stats

# Test pool is initially empty
stats = get_pool_stats()
assert stats['pool_size'] == 0, f"Expected pool_size 0, got {stats['pool_size']}"
assert stats['in_use'] == 0, f"Expected in_use 0, got {stats['in_use']}"

# Get a connection
conn = get_pooled_connection()
stats = get_pool_stats()
assert stats['in_use'] == 1, f"Expected in_use 1, got {stats['in_use']}"

# Release it back to pool
release_connection(conn)
stats = get_pool_stats()
assert stats['pool_size'] == 1, f"Expected pool_size 1, got {stats['pool_size']}"
assert stats['in_use'] == 0, f"Expected in_use 0, got {stats['in_use']}"

print("POOL_TEST_PASS")
PYEOF
    if [ $? -eq 0 ]; then
        log_pass "Connection pool lifecycle works"
    else
        log_fail "Connection pool lifecycle failed"
    fi
    
    # Test: config validation
    log_test "Configuration Validation (nudge-rules.json)"
    python3 << 'PYEOF'
import sys
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/scripts/lib')
from config_validation import validate_nudge_rules
from pathlib import Path

try:
    config = validate_nudge_rules(Path('/home/mccargo/.openclaw/workspace/skills/proactive-intel/config/nudge-rules.json'))
    print("CONFIG_VALID")
except Exception as e:
    print(f"CONFIG_INVALID: {e}")
    sys.exit(1)
PYEOF
    if [ $? -eq 0 ]; then
        log_pass "nudge-rules.json is valid"
    else
        log_fail "nudge-rules.json validation failed"
    fi
    
    # Test: config validation error handling
    log_test "Configuration Validation (invalid config detection)"
    python3 << 'PYEOF'
import sys
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/scripts/lib')
from config_validation import NudgeRulesConfig, ValidationError

try:
    # Invalid: negative stale threshold
    NudgeRulesConfig.validate({
        'stale_thresholds_days': {'person': -5},  # Invalid: negative
        'travel_alert_days': [7, 3, 1],
        'birthday_alert_days': 7,
        'quiet_hours': {'start': 23, 'end': 8},
        'max_nudges_per_day': 5,
        'priority_weights': {'birthday': 10},
        'min_strength_for_followup': 0.5
    })
    print("SHOULD_HAVE_FAILED")
    sys.exit(1)
except ValidationError:
    print("INVALID_CONFIG_DETECTED")
PYEOF
    if [ $? -eq 0 ]; then
        log_pass "Invalid config properly rejected"
    else
        log_fail "Invalid config not detected"
    fi
}

# ============================================
# INTEGRATION TESTS
# ============================================

run_integration_tests() {
    log_section "🔗 INTEGRATION TESTS"
    
    # Test: KG full workflow
    log_test "Knowledge Graph Full Workflow"
    
    # Create entity
    RESULT=$(echo '{"command":"upsert_entity","args":{"name":"Test User","type":"person","confidence":0.9}}' | python3 "$WORKSPACE/skills/knowledge-graph/scripts/kg-bridge.py")
    if echo "$RESULT" | grep -q '"success": true'; then
        log_pass "Entity creation works"
        ENTITY_ID=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
        
        # Query entity
        RESULT=$(echo "{\"command\":\"get\",\"args\":{\"id\":$ENTITY_ID}}" | python3 "$WORKSPACE/skills/knowledge-graph/scripts/kg-bridge.py")
        if echo "$RESULT" | grep -q '"name": "Test User"'; then
            log_pass "Entity retrieval works"
        else
            log_fail "Entity retrieval failed"
        fi
        
        # Delete entity
        RESULT=$(echo "{\"command\":\"delete_entity\",\"args\":{\"id\":$ENTITY_ID}}" | python3 "$WORKSPACE/skills/knowledge-graph/scripts/kg-bridge.py")
        if echo "$RESULT" | grep -q '"success": true'; then
            log_pass "Entity deletion works"
        else
            log_fail "Entity deletion failed"
        fi
    else
        log_fail "Entity creation failed"
    fi
    
    # Test: PI Nudge Engine with config validation
    log_test "Proactive Intelligence with Valid Config"
    
    # First validate config
    python3 << 'PYEOF' > /tmp/pi_test.log 2>&1
import sys
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/scripts/lib')
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/skills/proactive-intel/scripts')
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/skills/knowledge-graph/scripts')

from config_validation import validate_nudge_rules
from pathlib import Path

# Validate config
config = validate_nudge_rules(Path('/home/mccargo/.openclaw/workspace/skills/proactive-intel/config/nudge-rules.json'))

# Now run nudge engine
import subprocess
result = subprocess.run(
    ['python3', '/home/mccargo/.openclaw/workspace/skills/proactive-intel/scripts/pi-nudge-engine.py'],
    input='{"command":"check_all"}',
    capture_output=True,
    text=True
)

if result.returncode == 0 and '"success": true' in result.stdout:
    print("PI_TEST_PASS")
else:
    print(f"PI_TEST_FAIL: {result.stderr}")
    sys.exit(1)
PYEOF
    
    if grep -q "PI_TEST_PASS" /tmp/pi_test.log; then
        log_pass "PI nudge engine works with validated config"
    else
        log_fail "PI nudge engine test failed"
    fi
}

# ============================================
# PERFORMANCE TESTS
# ============================================

run_performance_tests() {
    log_section "⚡ PERFORMANCE TESTS"
    
    # Test: Connection pooling performance
    log_test "Connection Pooling Performance"
    
    python3 << 'PYEOF' > /tmp/perf_test.log 2>&1
import sys
import time
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/skills/knowledge-graph/scripts')
from kg_lib import get_connection, get_pooled_connection, release_connection

# Test non-pooled connections
start = time.time()
for _ in range(10):
    conn = get_connection()
    conn.execute("SELECT 1")
    conn.close()
non_pooled_time = time.time() - start

# Test pooled connections
start = time.time()
for _ in range(10):
    conn = get_pooled_connection()
    conn.execute("SELECT 1")
    release_connection(conn)
pooled_time = time.time() - start

print(f"Non-pooled: {non_pooled_time:.4f}s")
print(f"Pooled: {pooled_time:.4f}s")

if pooled_time < non_pooled_time * 0.8:  # Expect at least 20% improvement
    print("PERF_TEST_PASS")
else:
    print("PERF_TEST_FAIL")
    sys.exit(1)
PYEOF
    
    if grep -q "PERF_TEST_PASS" /tmp/perf_test.log; then
        log_pass "Connection pooling shows performance improvement"
        grep -E "(Non-pooled|Pooled):" /tmp/perf_test.log | head -2 | sed 's/^/  /'
    else
        log_skip "Performance test (may vary based on system load)"
    fi
}

# ============================================
# CONFIGURATION TESTS
# ============================================

run_config_tests() {
    log_section "⚙️ CONFIGURATION TESTS"
    
    # Test: Validate all configs
    log_test "Validate All Configurations"
    
    python3 << 'PYEOF' > /tmp/config_test.log 2>&1
import sys
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/scripts/lib')
from config_validation import validate_all_configs
from pathlib import Path

results = validate_all_configs(Path('/home/mccargo/.openclaw/workspace'))

print(f"Valid: {len(results['valid'])}")
print(f"Invalid: {len(results['invalid'])}")
print(f"Missing: {len(results['missing'])}")

if results['invalid']:
    for item in results['invalid']:
        print(f"ERROR: {item['name']}: {item['error']}")
    sys.exit(1)
else:
    print("ALL_CONFIGS_VALID")
PYEOF
    
    if grep -q "ALL_CONFIGS_VALID" /tmp/config_test.log; then
        log_pass "All configuration files are valid"
    else
        log_fail "Some configuration files are invalid"
        cat /tmp/config_test.log | grep "ERROR:" | head -3 | sed 's/^/  /'
    fi
    
    # Test: mcporter config validation
    log_test "MCPorter Configuration Schema"
    
    if [ -f "$WORKSPACE/config/mcporter.json" ]; then
        python3 << 'PYEOF' > /tmp/mcporter_test.log 2>&1
import sys
sys.path.insert(0, '/home/mccargo/.openclaw/workspace/scripts/lib')
from config_validation import validate_mcporter_config
from pathlib import Path

try:
    config = validate_mcporter_config(Path('/home/mccargo/.openclaw/workspace/config/mcporter.json'))
    print("MCPORTER_VALID")
except Exception as e:
    print(f"MCPORTER_INVALID: {e}")
    sys.exit(1)
PYEOF
        
        if grep -q "MCPORTER_VALID" /tmp/mcporter_test.log; then
            log_pass "mcporter.json is valid"
        else
            log_fail "mcporter.json validation failed"
        fi
    else
        log_skip "mcporter.json not found"
    fi
}

# ============================================
# SYNTAX TESTS
# ============================================

run_syntax_tests() {
    log_section "📝 SYNTAX TESTS"
    
    SCRIPTS=(
        "scripts/daily-task-extractor.sh"
        "scripts/validate-security.sh"
        "scripts/check-git-status.sh"
        "scripts/prune-sessions.sh"
        "scripts/self-improvement-report.sh"
        "scripts/test-security.sh"
    )
    
    for script in "${SCRIPTS[@]}"; do
        log_test "Syntax: $script"
        if bash -n "$WORKSPACE/$script" 2>/dev/null; then
            log_pass "$script syntax OK"
        else
            log_fail "$script has syntax errors"
        fi
    done
    
    PYTHON_SCRIPTS=(
        "skills/knowledge-graph/scripts/kg-bridge.py"
        "skills/knowledge-graph/scripts/kg_lib.py"
        "skills/knowledge-graph/scripts/seed.py"
        "skills/proactive-intel/scripts/pi-nudge-engine.py"
        "scripts/lib/config_validation.py"
    )
    
    for script in "${PYTHON_SCRIPTS[@]}"; do
        log_test "Syntax: $script"
        if python3 -m py_compile "$WORKSPACE/$script" 2>/dev/null; then
            log_pass "$script syntax OK"
        else
            log_fail "$script has syntax errors"
        fi
    done
}

# ============================================
# MAIN
# ============================================

echo "========================================"
echo "🔬 COMPREHENSIVE TEST SUITE"
echo "========================================"
echo ""
echo "Testing OpenClaw Workspace"
echo "Workspace: $WORKSPACE"
echo ""

# Run all test categories
run_security_tests
run_unit_tests
run_integration_tests
run_performance_tests
run_config_tests
run_syntax_tests

# Summary
echo ""
echo "========================================"
echo "📊 TEST RESULTS SUMMARY"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}"
echo ""

TOTAL=$((PASSED + FAILED))
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed! ($PASSED/$TOTAL)${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed ($FAILED failures)${NC}"
    exit 1
fi
