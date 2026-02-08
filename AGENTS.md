# Agent Instructions

Testing loop for Proxmox Datacenter Manager Lab.

## Quick Start

```bash
# Set root password
echo 'ROOT_PASSWORD=yourpassword' > .env

# Setup and start
mise setup
mise start

# Check status
mise status
```

## Available Tasks

Run `mise tasks` to see all available commands with descriptions.

## Testing Loop

1. `mise setup` - Create directories, verify container system
2. `mise start` - Start all containers, set passwords, configure remotes
3. `mise status` - Verify containers running and remotes connected
4. `mise urls` - Get access URLs
5. Test PDM web UI at https://localhost:8443
6. `mise shell` - Debug inside containers if needed
7. `mise stop` - Stop when done
8. `mise clean` - Remove containers (data persists)
9. `mise clean:data` - Reset all data (optional)

## Data Persistence

Data persists in `data/` directory across container restarts. Use `mise clean:data` to reset everything.

## Manual Remote Configuration

If auto-configuration fails, add remotes manually:

1. Access each PVE node and create an API token:
   - Datacenter > Permissions > API Tokens > Add
   - User: `root@pam`, Token ID: `pdm`, Privilege Separation: unchecked

2. In PDM, add each remote:
   - Configuration > Remotes > Add
   - ID: `pve-1`, Type: `Proxmox VE`
   - Auth ID: `root@pam!pdm`
   - Token: (from step 1)
   - Nodes: `<container-ip>:8006`

Use `mise status` to find container IPs and hostnames.
