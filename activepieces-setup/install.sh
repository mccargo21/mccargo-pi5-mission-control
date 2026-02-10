#!/bin/bash
# Activepieces Quick Install Script for Raspberry Pi 5
# Run with: bash install.sh

set -e

echo "============================================"
echo "  Activepieces Installer for Raspberry Pi  "
echo "============================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please don't run as root. Run as your normal user.${NC}"
    exit 1
fi

# Get Pi IP
PI_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}Detected IP: ${PI_IP}${NC}"
echo ""

# Step 1: Check/Install Docker
echo -e "${YELLOW}Step 1: Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}Docker already installed: $(docker --version)${NC}"
else
    echo "Docker not found. Installing..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed!${NC}"
    echo -e "${YELLOW}NOTE: You may need to log out and back in for docker group to take effect${NC}"
fi
echo ""

# Step 2: Create directories
echo -e "${YELLOW}Step 2: Creating directories...${NC}"
mkdir -p ~/.activepieces
mkdir -p ~/activepieces
echo -e "${GREEN}Done${NC}"
echo ""

# Step 3: Choose deployment type
echo -e "${YELLOW}Step 3: Choose deployment type${NC}"
echo "1) Simple (embedded database - easier, lighter)"
echo "2) Full (PostgreSQL + Redis - more robust)"
read -p "Enter choice [1/2]: " DEPLOY_CHOICE

if [ "$DEPLOY_CHOICE" == "2" ]; then
    echo ""
    echo -e "${YELLOW}Setting up full deployment...${NC}"
    
    # Generate secrets
    ENCRYPTION_KEY=$(openssl rand -hex 16)
    JWT_SECRET=$(openssl rand -hex 32)
    POSTGRES_PWD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
    
    # Create docker-compose.yml
    cat > ~/activepieces/docker-compose.yml << EOF
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
      - AP_ENCRYPTION_KEY=${ENCRYPTION_KEY}
      - AP_JWT_SECRET=${JWT_SECRET}
      - AP_ENVIRONMENT=prod
      - AP_FRONTEND_URL=http://${PI_IP}:8080
      - AP_WEBHOOK_TIMEOUT_SECONDS=30
      - AP_TRIGGER_DEFAULT_POLL_INTERVAL=5
      - AP_POSTGRES_DATABASE=activepieces
      - AP_POSTGRES_HOST=postgres
      - AP_POSTGRES_PORT=5432
      - AP_POSTGRES_USERNAME=postgres
      - AP_POSTGRES_PASSWORD=${POSTGRES_PWD}
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
      - POSTGRES_PASSWORD=${POSTGRES_PWD}
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

    # Save credentials
    cat > ~/activepieces/.credentials << EOF
# Activepieces Credentials - KEEP SECURE
AP_ENCRYPTION_KEY=${ENCRYPTION_KEY}
AP_JWT_SECRET=${JWT_SECRET}
POSTGRES_PASSWORD=${POSTGRES_PWD}
PI_IP=${PI_IP}
ACCESS_URL=http://${PI_IP}:8080
EOF
    chmod 600 ~/activepieces/.credentials
    
    echo -e "${GREEN}Configuration created at ~/activepieces/${NC}"
    echo ""
    echo -e "${YELLOW}Step 4: Starting Activepieces...${NC}"
    cd ~/activepieces
    docker compose pull
    docker compose up -d
    
else
    echo ""
    echo -e "${YELLOW}Setting up simple deployment...${NC}"
    
    # Check if container exists
    if docker ps -a --format '{{.Names}}' | grep -q '^activepieces$'; then
        echo "Removing existing container..."
        docker stop activepieces 2>/dev/null || true
        docker rm activepieces 2>/dev/null || true
    fi
    
    echo -e "${YELLOW}Step 4: Starting Activepieces...${NC}"
    docker pull activepieces/activepieces:latest
    docker run -d \
      --name activepieces \
      --restart unless-stopped \
      -p 8080:80 \
      -v ~/.activepieces:/root/.activepieces \
      -e AP_REDIS_TYPE=MEMORY \
      -e AP_DB_TYPE=PGLITE \
      -e AP_FRONTEND_URL="http://${PI_IP}:8080" \
      activepieces/activepieces:latest
      
    # Save info
    cat > ~/activepieces/.credentials << EOF
# Activepieces Access Info
DEPLOY_TYPE=simple
DATA_DIR=~/.activepieces
PI_IP=${PI_IP}
ACCESS_URL=http://${PI_IP}:8080
EOF
    chmod 600 ~/activepieces/.credentials
fi

# Step 5: Enable Docker on boot
echo ""
echo -e "${YELLOW}Step 5: Enabling Docker on boot...${NC}"
sudo systemctl enable docker
echo -e "${GREEN}Done${NC}"

# Step 6: Wait for startup
echo ""
echo -e "${YELLOW}Step 6: Waiting for Activepieces to start...${NC}"
sleep 10

# Check if running
if docker ps | grep -q activepieces; then
    echo ""
    echo "============================================"
    echo -e "${GREEN}  ✅ Activepieces is running!${NC}"
    echo "============================================"
    echo ""
    echo -e "  Access URL: ${GREEN}http://${PI_IP}:8080${NC}"
    echo ""
    echo "  First visit will prompt you to create an admin account."
    echo ""
    echo "  Credentials saved to: ~/activepieces/.credentials"
    echo ""
    echo "  Useful commands:"
    echo "    docker logs -f activepieces    # View logs"
    echo "    docker restart activepieces    # Restart"
    echo "    docker stop activepieces       # Stop"
    echo ""
else
    echo -e "${RED}Container may not have started properly.${NC}"
    echo "Check logs with: docker logs activepieces"
fi
