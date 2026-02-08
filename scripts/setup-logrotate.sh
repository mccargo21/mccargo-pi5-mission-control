#!/bin/bash
# Setup Logrotate for OpenClaw Workspace
# Run with: sudo bash setup-logrotate.sh

set -euo pipefail

echo "========================================="
echo "OpenClaw Logrotate Setup"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ ERROR: This script requires sudo/root privileges."
    echo "   Please run with: sudo bash $0"
    exit 1
fi

# Create logrotate config
echo "Creating logrotate configuration..."
cat > /etc/logrotate.d/openclaw-workspace << 'EOF'
# OpenClaw Workspace Log Rotation
# Rotates logs in /home/mccargo/.openclaw/workspace/logs/

/home/mccargo/.openclaw/workspace/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 mccargo mccargo
    sharedscripts
    postrotate
        # Optional: Restart services that might have log files open
        # systemctl reload openclaw-gateway 2>/dev/null || true
    endscript
}

# Keep mission control logs longer
/home/mccargo/.openclaw/workspace/skills/mission-control/assets/*.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 644 mccargo mccargo
}
EOF

echo "   ✅ Config written to /etc/logrotate.d/openclaw-workspace"

# Test logrotate configuration
echo ""
echo "Testing logrotate configuration..."
if logrotate -d /etc/logrotate.d/openclaw-workspace 2>&1 | grep -q "error"; then
    echo "   ❌ ERROR: logrotate configuration has errors!"
    logrotate -d /etc/logrotate.d/openclaw-workspace
    exit 1
else
    echo "   ✅ logrotate configuration is valid"
fi

# Show logrotate status
echo ""
echo "========================================="
echo "✅ Logrotate setup complete!"
echo "========================================="
echo ""
echo "Configuration details:"
echo "  - Daily log rotation"
echo "  - Keep 14 days of logs (14 rotated files)"
echo "  - Compress old logs (gzip)"
echo "  - Create new logs with 644 permissions"
echo ""
echo "To manually test logrotate:"
echo "  sudo logrotate -f /etc/logrotate.d/openclaw-workspace"
echo ""
echo "To view logrotate status:"
echo "  cat /var/lib/logrotate/status | grep openclaw"
echo "========================================="
