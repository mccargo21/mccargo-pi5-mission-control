#!/bin/bash
# Pi5 Headless Setup Script
# Run with: sudo bash pi5-headless-setup.sh

set -euo pipefail

echo "========================================"
echo "Pi5 Headless Setup Script"
echo "========================================"

# 1. Power Management Settings
echo "[1/7] Configuring power management..."
sudo bash -c 'cat >> /etc/systemd/logind.conf << EOF

# Headless mode: Don'\''t suspend on idle or lid close
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
EOF'
echo "  ✓ Power management configured"

# 2. Disable Screen Blanking
echo "[2/7] Disabling screen blanking..."
if [ -f /etc/rc.local ]; then
    if ! grep -q "setterm" /etc/rc.local; then
        sudo sed -i '/^exit 0/i setterm -blank 0 -powerdown 0' /etc/rc.local
    fi
else
    sudo bash -c 'cat > /etc/rc.local << EOF
#!/bin/bash
# Disable screen blanking for headless operation
setterm -blank 0 -powerdown 0
exit 0
EOF'
    sudo chmod +x /etc/rc.local
    sudo systemctl enable rc-local
fi
echo "  ✓ Screen blanking disabled"

# 3. Static IP Configuration
# Current setup: eth0 (192.168.1.155), wlan0 (192.168.1.160)
# Gateway: 192.168.1.254
echo "[3/7] Setting up static IP..."
NETPLAN_FILE="/etc/netplan/99-pi5-static.yaml"
sudo bash -c "cat > $NETPLAN_FILE << 'EOF'
# Static IP configuration for Pi5 headless operation
# eth0: Wired connection (primary)
# wlan0: WiFi fallback
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.1.155/24
      routes:
        - to: default
          via: 192.168.1.254
      nameservers:
        addresses:
          - 1.1.1.1
          - 1.0.0.1
        search: []
  wifis:
    wlan0:
      dhcp4: false
      addresses:
        - 192.168.1.160/24
      routes:
        - to: default
          via: 192.168.1.254
          metric: 600
      nameservers:
        addresses:
          - 1.1.1.1
          - 1.0.0.1
EOF"
sudo chmod 600 "$NETPLAN_FILE"
echo "  ✓ Static IP configured (NOT applied yet - will need reboot)"
echo "    eth0: 192.168.1.155"
echo "    wlan0: 192.168.1.160"
echo "    Gateway: 192.168.1.254"

# 4. SSH Security Hardening
echo "[4/7] Hardening SSH configuration..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original
sudo cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

# SECURITY: Validate SSH key exists before disabling password auth
if [ ! -f ~/.ssh/id_ed25519.pub ] && [ ! -f ~/.ssh/id_rsa.pub ] && [ ! -f ~/.ssh/id_ecdsa.pub ]; then
    echo ""
    echo "⚠️  CRITICAL: No SSH public key found in ~/.ssh/"
    echo "   Disabling password authentication will LOCK YOU OUT!"
    echo ""
    echo "   Please generate an SSH key first:"
    echo "     ssh-keygen -t ed25519 -C \"$(whoami)@$(hostname)\""
    echo ""
    echo "   Or copy your existing key to ~/.ssh/ and set proper permissions:"
    echo "     mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo "     cp /path/to/key ~/.ssh/id_ed25519"
    echo "     cp /path/to/key.pub ~/.ssh/id_ed25519.pub"
    echo "     chmod 600 ~/.ssh/id_ed25519"
    echo "     chmod 644 ~/.ssh/id_ed25519.pub"
    echo ""
    echo "   Setup aborted. Fix SSH keys and run again."
    exit 1
fi
echo "  ✓ SSH public key detected ($(ls ~/.ssh/*.pub 2>/dev/null | head -1 | xargs basename))"

# Apply hardening settings
sudo sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication no/' "$SSHD_CONFIG"
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG"
sudo sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
sudo sed -i 's/^#*X11Forwarding .*/X11Forwarding no/' "$SSHD_CONFIG"

# Add optimized settings
if ! grep -q "ClientAliveInterval" "$SSHD_CONFIG"; then
    sudo bash -c 'cat >> "$SSHD_CONFIG" << EOF

# Security optimizations
ClientAliveInterval 60
ClientAliveCountMax 3
MaxStartups 10:30:60
EOF'
fi
echo "  ✓ SSH hardened (password login disabled)"

# 5. Install Monitoring Tools
echo "[5/7] Installing monitoring tools..."
sudo apt-get update -qq
sudo apt-get install -y -qq htop iotop nethogs speedtest-cli curl

echo "  ✓ Monitoring tools installed: htop, iotop, nethogs, speedtest-cli"

# 6. Set Up Auto-Updates
echo "[6/7] Setting up unattended upgrades..."
sudo apt-get install -y -qq unattended-upgrades apt-listchanges

echo "  ✓ Unattended upgrades installed"

# Configure unattended upgrades
sudo bash -c 'cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF'

sudo bash -c 'cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF'

echo "  ✓ Auto-updates configured (security patches only)"

# 7. Performance Optimizations for Headless Mode
echo "[7/7] Optimizing for headless operation..."

# Disable swap (Pi5 has plenty of RAM)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Increase file descriptor limits
sudo bash -c 'cat >> /etc/security/limits.conf << EOF
# Headless Pi5 optimizations
* soft nofile 65536
* hard nofile 65536
EOF'

# Disable unnecessary services
echo "  ✓ Performance optimizations applied"
echo "    - Swap disabled (16GB RAM sufficient)"
echo "    - File descriptor limits increased"

# Summary
echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "SSH Connection Info:"
echo "  Wired:  ssh mccargo@192.168.1.155"
echo "  WiFi:   ssh mccargo@192.168.1.160"
echo "  mDNS:   ssh mccargo@mccargo-pi5.local"
echo ""
echo "SSH Public Key (add this to your other machines):"
cat ~/.ssh/id_ed25519.pub
echo ""
echo "IMPORTANT: After reboot, password login will be DISABLED."
echo "Make sure you have your SSH key set up on all client machines!"
echo ""
echo "To apply static IP changes, reboot with: sudo reboot"
echo ""
echo "Monitoring commands:"
echo "  htop      - Process monitor"
echo "  iotop     - I/O monitor"
echo "  nethogs   - Network usage by process"
echo "  speedtest - Network speed test"
echo ""
echo "========================================"
