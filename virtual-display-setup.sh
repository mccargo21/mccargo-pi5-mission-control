#!/bin/bash
# Virtual Display Setup for Pi5
# Allows GNOME Remote Desktop to work without physical monitor
# Run with: sudo bash virtual-display-setup.sh

set -euo pipefail

echo "========================================"
echo "Virtual Display Setup for GNOME Remote Desktop"
echo "========================================"

# 1. Install dummy video driver
echo "[1/5] Installing virtual display driver..."
sudo apt-get update -qq
sudo apt-get install -y xserver-xorg-video-dummy xserver-xorg-core x11-xserver-utils
echo "  ✓ Dummy driver installed"

# 2. Create X11 configuration for virtual display
echo "[2/5] Creating X11 configuration..."
sudo mkdir -p /etc/X11/xorg.conf.d
sudo bash -c 'cat > /etc/X11/xorg.conf.d/99-virtual-display.conf << EOF
# Virtual Display Configuration for Pi5 Headless
Section "Device"
    Identifier "DummyVideo"
    Driver "dummy"
    # Video memory
    VideoRam 256000
EndSection

Section "Monitor"
    Identifier "DummyMonitor"
    HorizSync 30-70
    VertRefresh 50-75
    # 1920x1080 resolution
    Modeline "1920x1080" 148.5 1920 2008 2052 2200 1080 1084 1089 1125
    Option "PreferredMode" "1920x1080"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "DummyVideo"
    Monitor "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Viewport 0 0
        Virtual 1920 1080
        Depth 24
        Modes "1920x1080"
    EndSubSection
EndSection
EOF'
echo "  ✓ X11 configuration created (1920x1080 virtual display)"

# 3. Enable and configure gdm (GNOME Display Manager)
echo "[3/5] Configuring GNOME Display Manager..."
if ! command -v gdm3 &> /dev/null; then
    sudo apt-get install -y gdm3
fi

# Configure gdm to start on boot
sudo systemctl enable gdm3
echo "  ✓ GDM enabled"

# 4. Configure systemd to start X server with virtual display
echo "[4/5] Setting up systemd service for virtual display..."
sudo bash -c 'cat > /etc/systemd/system/virtual-display.service << EOF
[Unit]
Description=Virtual Display Server for Remote Desktop
After=network.target

[Service]
Type=simple
User=gdm
Environment=DISPLAY=:0
ExecStart=/usr/bin/Xorg -config /etc/X11/xorg.conf.d/99-virtual-display.conf :0 vt7 -nolisten tcp -noreset
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF'

sudo systemctl enable virtual-display.service
echo "  ✓ Virtual display service created and enabled"

# 5. Ensure GNOME Remote Desktop starts automatically
echo "[5/5] Configuring GNOME Remote Desktop..."
sudo systemctl enable gnome-remote-desktop
echo "  ✓ GNOME Remote Desktop enabled"

# Summary
echo ""
echo "========================================"
echo "Virtual Display Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. After reboot, GNOME Remote Desktop will run on virtual display"
echo "3. Connect to your Pi5 using GNOME Remote Desktop"
echo ""
echo "Virtual display resolution: 1920x1080"
echo ""
echo "To check status after reboot:"
echo "  systemctl status gdm3"
echo "  systemctl status virtual-display"
echo "  systemctl status gnome-remote-desktop"
echo ""
echo "========================================"
