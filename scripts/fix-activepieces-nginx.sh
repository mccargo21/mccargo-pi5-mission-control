#!/bin/bash
# Fix ActivePieces nginx configuration - use port 8443 instead of 443

set -euo pipefail

NGINX_CONF="/etc/nginx/sites-available/activepieces"
BACKUP_DIR="/etc/nginx/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================="
echo "ActivePieces nginx Configuration Update"
echo "========================================="
echo ""

# 1. Check if running as root or with sudo
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    echo "❌ ERROR: This script requires sudo privileges."
    echo "   Please run with: sudo bash $0"
    exit 1
fi

# 2. Create backup directory if it doesn't exist
echo "[1/6] Creating backup directory..."
sudo mkdir -p "$BACKUP_DIR"
echo "   ✅ Backup directory: $BACKUP_DIR"

# 3. Backup existing configuration
echo "[2/6] Backing up existing configuration..."
if [ -f "$NGINX_CONF" ]; then
    BACKUP_FILE="$BACKUP_DIR/activepieces.backup.$TIMESTAMP"
    sudo cp "$NGINX_CONF" "$BACKUP_FILE"
    echo "   ✅ Backed up to: $BACKUP_FILE"
else
    echo "   ℹ️  No existing configuration found (will create new)"
fi

# 4. Write new configuration
echo "[3/6] Writing new nginx configuration..."
sudo tee "$NGINX_CONF" > /dev/null << 'EOF'
server {
    listen 80;
    server_name 192.168.1.155;
    return 301 https://$host:8443$request_uri;
}

server {
    listen 8443 ssl http2;
    server_name 192.168.1.155;

    ssl_certificate /etc/ssl/certs/activepieces-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/activepieces-selfsigned.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
echo "   ✅ Configuration written"

# 5. Validate configuration
echo "[4/6] Validating nginx configuration..."
if sudo nginx -t; then
    echo "   ✅ Configuration is valid"
else
    echo "   ❌ ERROR: nginx configuration validation failed!"
    echo "   Rolling back to previous configuration..."

    if [ -f "$BACKUP_FILE" ]; then
        sudo cp "$BACKUP_FILE" "$NGINX_CONF"
        echo "   ✅ Rolled back from backup"
    else
        echo "   ⚠️  No backup to restore (configuration may be broken)"
    fi

    echo ""
    echo "Please review the error output above and fix the configuration manually."
    exit 1
fi

# 6. Restart nginx
echo "[5/6] Restarting nginx..."
if sudo systemctl restart nginx; then
    echo "   ✅ nginx restarted successfully"
else
    echo "   ❌ ERROR: Failed to restart nginx!"
    echo "   Rolling back configuration and restarting..."

    if [ -f "$BACKUP_FILE" ]; then
        sudo cp "$BACKUP_FILE" "$NGINX_CONF"
        sudo systemctl restart nginx
        echo "   ✅ Rolled back and nginx restored"
    fi

    echo "Please check the nginx logs for more information:"
    echo "   sudo journalctl -u nginx -n 50"
    exit 1
fi

# 7. Open firewall port
echo "[6/6] Configuring firewall..."
if command -v ufw &>/dev/null; then
    sudo ufw allow 8443/tcp comment "ActivePieces https" >/dev/null 2>&1
    echo "   ✅ Port 8443 opened in firewall (ufw)"
else
    echo "   ℹ️  ufw not found, skipping firewall configuration"
fi

# 8. Verify nginx status
echo ""
echo "Verifying nginx status..."
if sudo systemctl is-active --quiet nginx; then
    echo "   ✅ nginx is running"
else
    echo "   ❌ nginx is NOT running!"
    echo "   Checking status..."
    sudo systemctl status nginx.service --no-pager || true
    exit 1
fi

# 9. Success message
echo ""
echo "========================================="
echo "✅ Configuration Update Complete!"
echo "========================================="
echo ""
echo "Access ActivePieces at: https://192.168.1.155:8443"
echo ""
echo "⚠️  Certificate Warning:"
echo "   You'll see a browser security warning (self-signed certificate)."
echo "   Click 'Advanced' → 'Proceed' to continue."
echo ""
echo "Backup location: $BACKUP_FILE"
echo ""
echo "To view nginx logs:"
echo "  sudo journalctl -u nginx -f"
echo ""
echo "To manually restart nginx:"
echo "  sudo systemctl restart nginx"
echo "========================================="
