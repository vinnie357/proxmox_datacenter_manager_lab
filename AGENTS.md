# Agent Instructions

Testing loop for Proxmox Datacenter Manager Lab.

## Commands

```bash
# Start the lab
mise start

# Check status and URLs
mise urls

# Stop the lab
mise stop
```

## Shell Access

```bash
mise shell        # PDM container
mise shell:pve1   # PVE-1 container
mise shell:pve2   # PVE-2 container
mise shell:pve3   # PVE-3 container
```

## Testing Loop

1. `mise start` - Start all containers
2. `mise urls` - Verify running and get access URLs
3. Test PDM web UI at the provided URL
4. `mise shell` - Debug inside containers if needed
5. `mise stop` - Stop when done
