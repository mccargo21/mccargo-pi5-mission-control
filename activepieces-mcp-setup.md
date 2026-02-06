# ActivePieces MCP Server Setup for OpenClaw

## Current Status

- ✅ ActivePieces is running and healthy
- ✅ ActivePieces API is accessible at `http://localhost:8080`
- ✅ SSL is configured for HTTPS at `https://192.168.1.155:8443`
- ❌ MCP endpoint `/api/v1/mcp` returns 404

## Next Steps

### 1. Enable MCP in ActivePieces

ActivePieces MCP support may need to be enabled in the application:

1. Log in to ActivePieces at `https://192.168.1.155:8443`
2. Go to **Settings** or **Admin** section
3. Look for **MCP**, **Integrations**, or **API** settings
4. Enable **MCP Server** if available
5. Note any API key or authentication token required for MCP access

### 2. Configure mcporter

Once MCP is enabled in ActivePieces, connect it via mcporter:

```bash
# If MCP requires authentication:
mcporter auth http://localhost:8080/api/v1/mcp --allow-http

# Or if it works as stdio:
mcporter config add activepieces --command="docker exec activepieces <mcp-command>"
```

### 3. Verify Connection

After configuration, list available tools:

```bash
mcporter list activepieces
```

Expected: Should show 600+ tools from ActivePieces

## Troubleshooting

If MCP endpoint still returns 404:

1. Check ActivePieces logs: `sudo docker logs activepieces`
2. Restart ActivePieces container: `sudo docker restart activepieces`
3. Check if MCP needs to be started as a separate service

## Documentation Links

- ActivePieces: https://docs.activepieces.com/
- MCP Protocol: https://modelcontextprotocol.com/
