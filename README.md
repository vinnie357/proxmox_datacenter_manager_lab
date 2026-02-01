# Proxmox Datacenter Manager Lab

Run Proxmox Datacenter Manager (PDM) and Proxmox VE nodes in containers for home lab testing.

## Quick Start (macOS 26+)

```bash
# Start the lab
mise start

# Check container status
mise status

# Show access URLs
mise urls

# Stop the lab
mise stop
```

Run `mise urls` to see access URLs and container status.

If a DNS domain is configured (`container system dns ls`), containers are also accessible via hostnames like `pdm.test.local`.

Shell access: `mise shell` (PDM) or `mise shell:pve1` (PVE-1)

Default credentials: `root` / `root`

## Requirements

### macOS 26+ (Tahoe) - Apple Container

Uses Apple's native containerization with Rosetta 2 for x86_64 emulation.

```bash
# Verify container command exists
container --version
```

### Linux/Windows - Docker

Use docker-compose directly:

```bash
docker compose up -d
```

## Commands

| Command | Description |
|---------|-------------|
| `mise start` | Start PDM + 3 PVE nodes |
| `mise stop` | Stop all containers |
| `mise status` | Show container status |
| `mise urls` | Show access URLs |
| `mise backup` | Backup PDM data |
| `mise clean` | Remove all containers |
| `mise shell` | Shell into PDM |

## Project Structure

```
├── docker-compose.yml   # For Docker (Linux/Windows)
├── mise.toml            # Task definitions
├── data/                # All persistent data (gitignored)
│   ├── backups/         # PDM backups
│   ├── ISOs/            # ISO storage for PVE
│   ├── pdm-config/      # PDM configuration
│   ├── pdm-data/        # PDM database
│   └── VM-Backup/       # VM backups
├── scripts/             # Nushell automation scripts
└── templates/           # Reference commands
```

## How It Works

### Apple Container (macOS 26+)

Uses three key flags:
- `--platform linux/amd64` - x86_64 image
- `--rosetta` - Rosetta 2 emulation
- `--virtualization` - Required for systemd

### Docker (Linux/Windows)

Standard docker-compose with privileged containers and cgroup mounts.

## Connecting PDM to PVE Nodes

1. Open PDM at https://localhost:8443
2. Add remotes using container IPs (visible in `mise status`)
3. Or use hostnames if on same Docker network

## Backup & Restore

```bash
# Backup running PDM data
mise backup

# Backups saved to data/backups/
```

## Sources

- [Run Proxmox Datacenter Manager in Docker](https://www.virtualizationhowto.com/2026/01/run-proxmox-datacenter-manager-in-a-docker-container-for-home-labs-and-testing/)
- [Run Proxmox Inside Docker](https://www.virtualizationhowto.com/2026/01/run-proxmox-inside-docker-a-weekend-home-lab-project-to-learn-clustering-and-ha/)
- [Proxmox Datacenter Manager](https://www.proxmox.com/en/products/proxmox-datacenter-manager/overview)
- [PDM Documentation](https://pdm.proxmox.com/docs/)
- [Container Images](https://github.com/longqt-sea)
