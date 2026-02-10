# Activepieces Setup for Raspberry Pi 5

## Summary

This directory contains everything needed to install and run Activepieces on Adam's Raspberry Pi 5.

## Files

- **INSTALL.md** - Comprehensive installation guide with step-by-step instructions
- **install.sh** - Automated installation script (run with `bash install.sh`)
- **README.md** - This file

## Quick Start

```bash
cd /home/mccargo/.openclaw/workspace/activepieces-setup
bash install.sh
```

The script will:
1. Install Docker if needed
2. Let you choose simple or full deployment
3. Configure and start Activepieces
4. Enable auto-start on boot

## System Status

| Check | Status |
|-------|--------|
| RAM | ✅ 7.8GB available |
| Disk | ✅ 95GB available |
| CPU | ✅ 4 cores |
| OS | ✅ Ubuntu 24.04 LTS |
| Docker | ❌ Needs installation |

## Access Information

After installation:
- **URL**: `http://<PI_IP>:8080`
- **Port**: 8080
- **License**: MIT (Free Community Edition)

First visit prompts admin account creation - credentials are user-defined.

## MCP Integration

Activepieces supports MCP (Model Context Protocol) and can serve as an MCP server with 625+ tool integrations. The API is available at:
- API Base: `http://<PI_IP>:8080/api/v1/`
- MCP endpoint: `http://<PI_IP>:8080/api/v1/mcp`

## Resource Requirements

- **RAM**: 500MB-2GB depending on load
- **Disk**: ~5GB (image + data)
- **CPU**: Minimal idle, spikes during automation runs

The Pi 5 with 8GB RAM easily handles Activepieces.
