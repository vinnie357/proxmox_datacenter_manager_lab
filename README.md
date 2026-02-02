# Proxmox Datacenter Manager Lab

Run Proxmox Datacenter Manager (PDM), Proxmox VE nodes, and Proxmox Backup Server (PBS) in containers for home lab testing.

## Quick Start (macOS 26+)

```bash
# Set your root password
echo 'ROOT_PASSWORD=yourpassword' > .env

# Create volumes and directories
mise setup

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
| `mise pve:init` | Initialize PVE nodes (FQDN + cluster setup) |
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
└── data/                # Persistent data (gitignored)
    ├── backups/         # mise backup output
    ├── pve-1/           # PVE node 1 storage
    │   ├── iso/         # ISO images
    │   └── dump/        # VM backups
    ├── pve-2/           # PVE node 2 storage
    └── pve-3/           # PVE node 3 storage
```

### Storage by Platform

| Container | Apple Container | Docker |
|-----------|-----------------|--------|
| PDM | Named volume: `pdm-data` | Bind: `data/pdm-data` |
| PVE | Bind: `data/pve-{n}/iso`, `data/pve-{n}/dump` | Bind: `data/ISOs`, `data/VM-Backup` (shared) |
| PBS | Named volumes: `pbs-lib`, `pbs-backups` | Bind: `data/pbs-lib`, `data/pbs-backups` |

Use `mise clean:data` to reset all persistent data (removes volumes and clears directories).

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

## Troubleshooting

### PVE Nodes Show "Unknown" Status

If PVE nodes appear offline or show "unknown" status in PDM:

1. **FQDN Requirement**: PVE requires `hostname -f` to return a fully qualified domain name
2. **Local Cluster**: Each node needs a cluster initialized for RRD data

Run `mise pve:init` to fix both issues, or manually:

```bash
# Inside the PVE container
# 1. Fix /etc/hosts with FQDN
IP=$(hostname -I | awk '{print $1}')
echo "$IP pve-1.local pve-1" >> /etc/hosts

# 2. Initialize local cluster
pvecm create pve-1cluster --link0 $IP

# 3. Restart status daemon
systemctl restart pvestatd
```

### Journald Crashes (Rosetta 2)

Expected behavior under Rosetta 2 - systemd-journald crashes with SIGTRAP due to unsupported syscalls. The custom PVE image includes rsyslog as a workaround with journald configured to forward to syslog.

## Sources

- [Run Proxmox Datacenter Manager in Docker](https://www.virtualizationhowto.com/2026/01/run-proxmox-datacenter-manager-in-a-docker-container-for-home-labs-and-testing/)
- [Run Proxmox Inside Docker](https://www.virtualizationhowto.com/2026/01/run-proxmox-inside-docker-a-weekend-home-lab-project-to-learn-clustering-and-ha/)
- [Proxmox Datacenter Manager](https://www.proxmox.com/en/products/proxmox-datacenter-manager/overview)
- [PDM Documentation](https://pdm.proxmox.com/docs/)
- [Containerized Proxmox](https://github.com/LongQT-sea/containerized-proxmox) - Container images for PVE and PDM
- [Proxmox Backup Server Dockerfiles](https://github.com/ayufan/pve-backup-server-dockerfiles) - Unofficial PBS container image
- [Node Seems to be Offline - Proxmox Forum](https://forum.proxmox.com/threads/node-seems-to-be-offline.102216/) - FQDN hostname fix
- [PVE Container RRD Fix](https://chrichri.ween.de/o/b545ee3dc6664f0fbd581805c9cb3ebf) - Local cluster initialization for RRD data
