#!/bin/bash
# Security Validation Script
# Checks security posture after Priority 1 fixes

WORKSPACE="/home/mccargo/.openclaw/workspace"
EXIT_CODE=0

echo "========================================="
echo "Security Validation Check"
echo "========================================="
echo ""

# 0. Check .env.secrets permissions
echo "[0/7] Checking .env.secrets permissions..."
if [ -f "/home/mccargo/.openclaw/.env.secrets" ]; then
    PERMS=$(stat -c "%a" "/home/mccargo/.openclaw/.env.secrets" 2>/dev/null || stat -f "%OLp" "/home/mccargo/.openclaw/.env.secrets")
    if [ "$PERMS" = "600" ]; then
        echo "   ✅ .env.secrets: Owner-only (600)"
    else
        echo "   ❌ .env.secrets: Insecure permissions ($PERMS), should be 600"
        EXIT_CODE=1
    fi
else
    echo "   ❌ .env.secrets: Not found! Secrets may be hardcoded in openclaw.json"
    EXIT_CODE=1
fi

# Check openclaw.json doesn't contain raw secrets
echo "[0b/7] Checking openclaw.json for hardcoded secrets..."
if grep -qE '"(botToken|token|apiKey)":\s*"[^$]' "/home/mccargo/.openclaw/openclaw.json" 2>/dev/null; then
    echo "   ❌ openclaw.json contains hardcoded secrets (not using \${} references)"
    EXIT_CODE=1
else
    echo "   ✅ openclaw.json uses env var references for secrets"
fi

# 1. Check mcporter.json permissions
echo "[1/6] Checking mcporter.json permissions..."
if [ -f "$WORKSPACE/config/mcporter.json" ]; then
    PERMS=$(stat -c "%a" "$WORKSPACE/config/mcporter.json" 2>/dev/null || stat -f "%OLp" "$WORKSPACE/config/mcporter.json")
    if [ "$PERMS" = "600" ]; then
        echo "   ✅ mcporter.json: Owner-only (600)"
    else
        echo "   ❌ mcporter.json: Insecure permissions ($PERMS), should be 600"
        EXIT_CODE=1
    fi
else
    echo "   ⚠️  mcporter.json: Not found"
fi

# 2. Check mcporter-activepieces.json permissions
echo "[2/6] Checking mcporter-activepieces.json permissions..."
if [ -f "$WORKSPACE/config/mcporter-activepieces.json" ]; then
    PERMS=$(stat -c "%a" "$WORKSPACE/config/mcporter-activepieces.json" 2>/dev/null || stat -f "%OLp" "$WORKSPACE/config/mcporter-activepieces.json")
    if [ "$PERMS" = "600" ]; then
        echo "   ✅ mcporter-activepieces.json: Owner-only (600)"
    else
        echo "   ❌ mcporter-activepieces.json: Insecure permissions ($PERMS), should be 600"
        EXIT_CODE=1
    fi
else
    echo "   ⚠️  mcporter-activepieces.json: Not found"
fi

# 3. Check that config directory is gitignored
echo "[3/6] Checking config/ gitignore status..."
cd "$WORKSPACE"
if git check-ignore -q config/ 2>/dev/null; then
    echo "   ✅ config/ is gitignored"
else
    echo "   ❌ config/ is NOT gitignored - sensitive files may be committed!"
    EXIT_CODE=1
fi

# 4. Check for staged config files in git
echo "[4/6] Checking for staged config files..."
if git status --porcelain config/ 2>/dev/null | grep -q .; then
    echo "   ❌ Config files are staged in git! Run 'git reset config/' to unstage"
    EXIT_CODE=1
else
    echo "   ✅ No config files staged"
fi

# 5. Check that setup scripts have error handling
echo "[5/6] Checking script error handling..."
ERROR_HANDLING_OK=true

# Workspace scripts
for script in "pi5-headless-setup.sh" "virtual-display-setup.sh" \
             "scripts/openclaw-update.sh" "scripts/openclaw-update-recap.sh" \
             "scripts/fix-activepieces-nginx.sh" "scripts/check-git-status.sh" \
             "scripts/daily-task-extractor.sh" "scripts/prune-sessions.sh" \
             "scripts/self-improvement-report.sh" "scripts/mc-create-task.sh"; do
    if [ -f "$WORKSPACE/$script" ]; then
        if grep -q "set -euo pipefail\|set -eo pipefail\|set -e" "$script"; then
            echo "   ✅ $script: Has error handling"
        else
            echo "   ⚠️  $script: Missing error handling (set -euo pipefail)"
            ERROR_HANDLING_OK=false
        fi
    else
        echo "   ⚠️  $script: Not found"
    fi
done

# Mission Control scripts
for script in "skills/mission-control/scripts/mc-update.sh" \
             "skills/mission-control/scripts/sync-to-opensource.sh" \
             "skills/mission-control/scripts/update-version.sh"; do
    if [ -f "$WORKSPACE/$script" ]; then
        if grep -q "set -euo pipefail\|set -eo pipefail\|set -e" "$script"; then
            echo "   ✅ $script: Has error handling"
        else
            echo "   ⚠️  $script: Missing error handling (set -euo pipefail)"
            ERROR_HANDLING_OK=false
        fi
    else
        echo "   ⚠️  $script: Not found"
    fi
done

if [ "$ERROR_HANDLING_OK" = false ]; then
    EXIT_CODE=1
fi

# 6. Check SSH key validation in pi5 setup script
echo "[6/6] Checking SSH lockout protection..."
if [ -f "$WORKSPACE/pi5-headless-setup.sh" ]; then
    if grep -q "No SSH public key found" "$WORKSPACE/pi5-headless-setup.sh"; then
        echo "   ✅ pi5-headless-setup.sh: Has SSH key validation"
    else
        echo "   ❌ pi5-headless-setup.sh: Missing SSH key validation (lockout risk)"
        EXIT_CODE=1
    fi
else
    echo "   ⚠️  pi5-headless-setup.sh: Not found"
fi

# 7. Check nginx script has backup and validation
echo "[7/7] Checking nginx script safety..."
if [ -f "$WORKSPACE/scripts/fix-activepieces-nginx.sh" ]; then
    if grep -q "nginx -t" "$WORKSPACE/scripts/fix-activepieces-nginx.sh" && \
       grep -q "Rolling back" "$WORKSPACE/scripts/fix-activepieces-nginx.sh"; then
        echo "   ✅ fix-activepieces-nginx.sh: Has validation and rollback"
    else
        echo "   ❌ fix-activepieces-nginx.sh: Missing validation or rollback"
        EXIT_CODE=1
    fi
else
    echo "   ⚠️  fix-activepieces-nginx.sh: Not found"
fi

echo ""
echo "========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All security checks passed!"
    echo "   Priority 1 security fixes are complete."
else
    echo "❌ Security validation failed!"
    echo "   Review issues above and address them."
fi
echo "========================================="

exit $EXIT_CODE
