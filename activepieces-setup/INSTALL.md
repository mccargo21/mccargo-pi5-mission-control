# Activepieces Installation Guide for Raspberry Pi 5

## System Requirements ✅

**Your Pi 5 Status:**
- ✅ RAM: 7.8GB (minimum 2GB, 4GB+ recommended)
- ✅ Disk: 95GB available (needs ~5GB)
- ✅ CPU: 4 cores (excellent for Pi 5)
- ✅ OS: Ubuntu 24.04 LTS (Noble) - fully supported

---

## Step 1: Install Docker

Docker is not currently installed on the system. Run these commands:

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install Docker using the official script
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh

# Add your user to the docker group (avoids needing sudo)
sudo usermod -aG docker $USER

# IMPORTANT: Log out and back in, or run:
newgrp docker

# Verify installation
docker --version
docker run hello-world
```

---

## Step 2: Create Activepieces Directory

```bash
mkdir -p ~/activepieces
cd ~/activepieces
```

---

## Step 3: Simple Deployment (Recommended for Pi)

This uses the lightweight single-container approach with embedded database:

```bash
# Create the data directory
mkdir -p ~/.activepieces

# Run Activepieces
docker run -d \
  --name activepieces \
  --restart unless-stopped \
  -p 8080:80 \
  -v ~/.activepieces:/root/.activepieces \
  -e AP_REDIS_TYPE=MEMORY \
  -e AP_DB_TYPE=PGLITE \
  -e AP_FRONTEND_URL="http://YOUR_PI_IP:8080" \
  activepieces/activepieces:latest
```

**Replace `YOUR_PI_IP` with your Pi's IP address!**

Find your IP with:
```bash
hostname -I | awk '{print $1}'
```

---

## Step 4: Full Production Deployment (Optional)

For more robust setup with PostgreSQL and Redis:

### 4a. Create docker-compose.yml

```bash
cat > ~/activepieces/docker-compose.yml << 'EOF'
services:
  activepieces:
    image: activepieces/activepieces:latest
    container_name: activepieces
    restart: unless-stopped
    ports:
      - '8080:80'
    depends_on:
      - postgres
      - redis
    environment:
      - AP_ENGINE_EXECUTABLE_PATH=dist/packages/engine/main.js
      - AP_ENCRYPTION_KEY=${AP_ENCRYPTION_KEY}
      - AP_JWT_SECRET=${AP_JWT_SECRET}
      - AP_ENVIRONMENT=prod
      - AP_FRONTEND_URL=http://${PI_IP}:8080
      - AP_WEBHOOK_TIMEOUT_SECONDS=30
      - AP_TRIGGER_DEFAULT_POLL_INTERVAL=5
      - AP_POSTGRES_DATABASE=activepieces
      - AP_POSTGRES_HOST=postgres
      - AP_POSTGRES_PORT=5432
      - AP_POSTGRES_USERNAME=postgres
      - AP_POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - AP_EXECUTION_MODE=UNSANDBOXED
      - AP_REDIS_HOST=redis
      - AP_REDIS_PORT=6379
      - AP_FLOW_TIMEOUT_SECONDS=600
      - AP_TELEMETRY_ENABLED=false
    volumes:
      - ./cache:/usr/src/app/cache
    networks:
      - activepieces

  postgres:
    image: postgres:14.4
    container_name: activepieces-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_DB=activepieces
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_USER=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - activepieces

  redis:
    image: redis:7.0.7
    container_name: activepieces-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - activepieces

volumes:
  postgres_data:
  redis_data:

networks:
  activepieces:
EOF
```

### 4b. Create .env file

```bash
# Generate secure keys
ENCRYPTION_KEY=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)
POSTGRES_PWD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
PI_IP=$(hostname -I | awk '{print $1}')

cat > ~/activepieces/.env << EOF
AP_ENCRYPTION_KEY=${ENCRYPTION_KEY}
AP_JWT_SECRET=${JWT_SECRET}
POSTGRES_PASSWORD=${POSTGRES_PWD}
PI_IP=${PI_IP}
EOF

# Save credentials for reference
echo "=== SAVE THESE CREDENTIALS ===" 
cat ~/activepieces/.env
echo "================================"
```

### 4c. Start the stack

```bash
cd ~/activepieces
docker compose up -d

# Watch logs
docker compose logs -f activepieces
```

---

## Step 5: Configure Auto-Start on Boot

Docker already handles restarts with `--restart unless-stopped`, but to ensure Docker starts on boot:

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

For the simple deployment, create a systemd service:

```bash
sudo tee /etc/systemd/system/activepieces.service << 'EOF'
[Unit]
Description=Activepieces Automation
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start activepieces
ExecStop=/usr/bin/docker stop activepieces

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable activepieces
```

---

## Step 6: Access Activepieces

1. Open a browser and go to: `http://YOUR_PI_IP:8080`
2. Create your admin account (first user becomes admin)
3. Start building automations!

---

## MCP Integration

Activepieces has built-in MCP (Model Context Protocol) support. It functions as an MCP server with 400+ tool integrations.

### Using Activepieces as MCP Server

Once running, Activepieces exposes an MCP-compatible endpoint. You can:

1. **Connect AI Agents** - Point your AI tools to Activepieces to use its 625+ integrations
2. **Create HTTP Webhooks** - Build flows triggered by HTTP requests
3. **Use the API** - REST API at `http://YOUR_PI_IP:8080/api/v1/`

### API Key Setup (Optional)

For programmatic access:
1. Go to Settings → API Keys in the Activepieces UI
2. Generate a new API key
3. Use it in your integrations with header: `Authorization: Bearer YOUR_API_KEY`

### MCP Configuration Example

For Claude Desktop or other MCP clients:

```json
{
  "mcpServers": {
    "activepieces": {
      "url": "http://YOUR_PI_IP:8080/api/v1/mcp",
      "transport": "http"
    }
  }
}
```

---

## Useful Commands

```bash
# Check status
docker ps -a | grep activepieces

# View logs
docker logs -f activepieces

# Restart
docker restart activepieces

# Stop
docker stop activepieces

# Update to latest version
docker pull activepieces/activepieces:latest
docker stop activepieces
docker rm activepieces
# Then run the docker run command again

# Backup data (simple deployment)
cp -r ~/.activepieces ~/.activepieces-backup-$(date +%Y%m%d)

# Backup data (full deployment)
cd ~/activepieces && docker compose down
tar -czvf activepieces-backup-$(date +%Y%m%d).tar.gz .env cache/
docker compose up -d
```

---

## Troubleshooting

### Container won't start
```bash
docker logs activepieces
```
Check for port conflicts or permission issues.

### Port 8080 already in use
Change the port mapping:
```bash
docker run ... -p 8081:80 ...
```
Then access via `http://YOUR_PI_IP:8081`

### Out of memory
The Pi has 8GB which is plenty, but if issues occur:
```bash
# Check memory usage
docker stats activepieces

# Add swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab
```

### Database corruption (simple deployment)
```bash
docker stop activepieces
rm -rf ~/.activepieces
docker start activepieces
# Note: This resets everything!
```

### Container keeps restarting
```bash
docker logs activepieces --tail 100
docker inspect activepieces | grep -A 5 "State"
```

---

## Resource Usage

Expected resource consumption on Pi 5:
- **RAM**: ~500MB-1GB idle, up to 2GB under load
- **CPU**: Minimal idle, spikes during flow execution
- **Disk**: ~2GB for Docker image + database growth
- **Network**: Depends on automations

---

## Quick Reference

| Item | Value |
|------|-------|
| Web UI | `http://YOUR_PI_IP:8080` |
| API Base | `http://YOUR_PI_IP:8080/api/v1/` |
| Data Location (simple) | `~/.activepieces` |
| Data Location (full) | `~/activepieces/` |
| Docker Container | `activepieces` |
| Default Port | `8080` |
| License | MIT (Community Edition - Free) |

---

## Next Steps

1. ✅ Install Docker
2. ✅ Run Activepieces container
3. Create your first automation flow
4. Connect your favorite apps (625+ integrations)
5. Set up webhooks for external triggers
6. Configure MCP for AI agent integration

**Documentation**: https://www.activepieces.com/docs  
**Pieces Library**: https://www.activepieces.com/pieces  
**GitHub**: https://github.com/activepieces/activepieces
