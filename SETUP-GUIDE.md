# Pi5 Headless Setup - Quick Start Guide

## What's Been Done ✅

1. **SSH Keys Generated** - Ed25519 key pair created (modern, secure)
2. **Setup Script Created** - `pi5-headless-setup.sh` ready to run
3. **Public Key Saved** - Copy to your other machines

## Step 1: Run the Setup Script

SSH into your Pi5 and run:

```bash
cd ~/.openclaw/workspace
sudo bash pi5-headless-setup.sh
```

This will:
- Disable sleep/suspend and screen blanking
- Set up static IPs (eth0: 192.168.1.155, wlan0: 192.168.1.160)
- Harden SSH (password auth disabled, key-only)
- Install monitoring tools (htop, iotop, nethogs, speedtest-cli)
- Configure automatic security updates
- Optimize performance (disable swap, increase file limits)

## Step 2: Add SSH Key to Your Other Machines

**From your laptop/desktop:**

Copy the public key (`SSH-PUBLIC-KEY.txt`) and add it to `~/.ssh/authorized_keys` on any machine you want to SSH FROM.

Or, if you want to copy the key from your Pi5:

```bash
# On Pi5, display the key
cat ~/.ssh/id_ed25519.pub
```

Then add that line to `~/.ssh/authorized_keys` on your other machines.

## Step 3: Reboot to Apply Changes

```bash
sudo reboot
```

After reboot:
- Static IP will be active
- SSH password login will be **disabled** (key-only)
- Auto-updates will run automatically

## SSH Connection Methods

```bash
# Wired
ssh mccargo@192.168.1.155

# WiFi
ssh mccargo@192.168.1.160

# mDNS (if supported)
ssh mccargo@mccargo-pi5.local
```

## Monitoring Commands

```bash
htop      # Process and resource monitor
iotop     # I/O usage by process
nethogs   # Network bandwidth by process
speedtest # Network speed test
```

## Recovery Options

If you get locked out of SSH:

1. Connect a keyboard and monitor directly to the Pi5
2. Login and re-enable password auth:
   ```bash
   sudo nano /etc/ssh/sshd_config
   # Change: PasswordAuthentication yes
   sudo systemctl restart ssh
   ```

## What Changed

| Setting | Before | After |
|---------|--------|-------|
| Static IP | DHCP | 192.168.1.155 (wired) / 192.168.1.160 (wifi) |
| SSH Auth | Password | SSH Key Only |
| Auto-Updates | Manual | Automatic (security only) |
| Sleep | Default | Disabled |
| Swap | Enabled | Disabled (16GB RAM enough) |

## Files Created

- `pi5-headless-setup.sh` - Main setup script
- `SSH-PUBLIC-KEY.txt` - Your SSH public key

## Next Steps

1. Run the setup script with sudo
2. Add SSH key to your client machines
3. Reboot
4. Test SSH connection from another machine
5. Enjoy your rock-solid headless Pi5!
