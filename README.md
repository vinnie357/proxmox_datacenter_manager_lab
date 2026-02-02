# Proxmox Datacenter Manager Lab

Run Proxmox Datacenter Manager (PDM), Proxmox VE nodes, and Proxmox Backup Server (PBS) in containers for home lab testing.

## Quick Start (macOS 26+)

```bash
# Set your root password
echo 'ROOT_PASSWORD=yourpassword' > .env

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

Shell access: `mise shell` (PDM), `mise shell:pve1` (PVE-1), `mise shell:pbs` (PBS)

Credentials are set from `ROOT_PASSWORD` in `.env` file. Run `mise urls` to see login details.

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
| `mise start` | Start PDM + 3 PVE nodes + PBS, set passwords, configure remotes |
| `mise stop` | Stop all containers |
| `mise status` | Show container status |
| `mise urls` | Show access URLs and credentials |
| `mise remotes:status` | Show PDM remote connection status |
| `mise passwd` | Set root passwords on running containers |
| `mise remotes` | Configure PVE/PBS nodes as remotes in PDM |
| `mise backup` | Backup PDM data |
| `mise clean` | Remove all containers |
| `mise clean:data` | Reset all persistent data |
| `mise download:images` | Download minimal test images |
| `mise shell` | Shell into PDM |
| `mise shell:pbs` | Shell into PBS |

## Project Structure

```
├── .env                 # ROOT_PASSWORD and other settings
├── docker-compose.yml   # For Docker (Linux/Windows)
├── mise.toml            # Task definitions
├── scripts/             # Nushell automation scripts
├── templates/           # Reference commands
└── data/                # Persistent data (gitignored)
    ├── pdm-config/      # PDM configuration
    ├── pdm-data/        # PDM database
    ├── backups/         # mise backup output
    ├── iso/             # ISO images (shared by all PVE nodes)
    ├── pve-{1,2,3}/dump # Per-node VM backups
    ├── pbs-config/      # PBS configuration
    ├── pbs-lib/         # PBS metadata
    ├── pbs-logs/        # PBS logs
    └── pbs-backups/     # PBS backup storage
```

Data persists in the `data/` directory across container restarts. Use `mise clean:data` to reset all persistent data.

## How It Works

### Apple Container (macOS 26+)

Uses three key flags:
- `--platform linux/amd64` - x86_64 image
- `--rosetta` - Rosetta 2 emulation
- `--virtualization` - Required for systemd

### Docker (Linux/Windows)

Standard docker-compose with privileged containers and cgroup mounts.

## Connecting PDM to PVE/PBS Nodes

Remotes are configured automatically during `mise start`. To check status:

```bash
mise remotes:status
```

To reconfigure manually:

```bash
mise remotes
```

See `AGENTS.md` for manual configuration steps if auto-config fails.

## Download Test Images

Download minimal test images for VM and container testing:

```bash
mise download:images
```

This downloads:
- **Tiny Core Linux ISO** (~24MB) - Smallest practical Linux for VM testing
  - Source: http://tinycorelinux.net/
  - Requires only 256MB RAM
  - Reference: [TinyCore VM Testing](https://enterpriseadmins.org/blog/lab-infrastructure/lightweight-vm-for-testing-tinycore-linux/)

For LXC containers, run inside a PVE node:
```bash
pveam update
pveam download local alpine-3.21-default_20250108_amd64.tar.xz
```

- **Alpine Linux LXC** (~3-4MB compressed) - Smallest LXC template
  - Source: https://images.linuxcontainers.org/
  - Reference: [Container Size Comparison](https://nelsonslog.wordpress.com/2023/12/14/proxmox-linux-container-sizes-alpine-etc/)

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
- [Containerized Proxmox](https://github.com/LongQT-sea/containerized-proxmox) - Container images for PVE and PDM
- [Proxmox Backup Server Dockerfiles](https://github.com/ayufan/pve-backup-server-dockerfiles) - Unofficial PBS container image
