# Agent Instructions

Testing loop for Proxmox Datacenter Manager Lab.

## Commands

```bash
# Start the lab (includes password setup and remote configuration)
mise start

# Check status and URLs
mise urls

# Stop the lab
mise stop
```

## Configuration Tasks

```bash
# Set root passwords on running containers
mise passwd

# Configure PVE nodes as remotes in PDM
mise remotes

# Show remote connection status
mise remotes:status
```

## Shell Access

```bash
mise shell        # PDM container
mise shell:pve1   # PVE-1 container
mise shell:pve2   # PVE-2 container
mise shell:pve3   # PVE-3 container
mise shell:pbs    # PBS container
```

## Testing Loop

1. `mise start` - Start all containers, set passwords, configure remotes
2. `mise urls` - Verify running and get access URLs
3. Test PDM web UI at the provided URL
4. `mise shell` - Debug inside containers if needed
5. `mise stop` - Stop when done

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

Use `mise status` to find container IPs.
