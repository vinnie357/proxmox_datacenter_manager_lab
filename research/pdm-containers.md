# Proxmox Datacenter Manager (PDM) Research

## Overview

Proxmox Datacenter Manager is a centralized management solution for multiple Proxmox VE nodes and clusters. It can be run in containers for home lab testing.

## Container Images

| Image | Purpose |
|-------|---------|
| `ghcr.io/longqt-sea/proxmox-datacenter-manager` | PDM management interface |
| `ghcr.io/longqt-sea/proxmox-ve` | Proxmox VE node (for testing clusters) |

## macOS 26+ (Tahoe) - Apple Container

**Recommended for Apple Silicon Macs.**

macOS 26 introduced native containerization with Rosetta 2 x86_64 emulation.

### Key Requirements

```bash
container run -d \
  --platform linux/amd64 \
  --rosetta \
  --virtualization \    # CRITICAL - required for systemd
  ...
```

| Flag | Purpose |
|------|---------|
| `--platform linux/amd64` | Use x86_64 image |
| `--rosetta` | Enable Rosetta 2 emulation |
| `--virtualization` | **Required** - enables systemd/init to work |

### What Works

| Component | Status |
|-----------|--------|
| PDM container | ✅ Working |
| PVE containers | ✅ Working |
| systemd services | ✅ Working (with --virtualization) |
| Web UI (port 8443/8006) | ✅ Working |
| Volume mounts | ✅ Working |

### Quick Start

```bash
cd ~/scratch/proxmox_datacenter_manager
mise start
```

See `templates/container-commands.md` for manual commands.

## Alternative: Docker/Colima (x86_64 Linux)

For x86_64 Linux hosts or VMs, see `examples/docker-compose/docker-compose.yml`.

**Note:** Colima on Apple Silicon has x86_64 emulation issues with these images.

## PDM State & Backup

### Configuration Paths

| Path | Contents |
|------|----------|
| `/etc/proxmox-datacenter-manager/` | Config files (remotes.cfg, views.cfg) |
| `/var/lib/proxmox-datacenter-manager/` | Runtime state/database |
| `/var/log/proxmox-datacenter-manager/` | Logs |

### Backup Strategy

Mount these paths as volumes to persist and backup:

```bash
-v ./pdm-config:/etc/proxmox-datacenter-manager
-v ./pdm-data:/var/lib/proxmox-datacenter-manager
```

For Synology NAS failover:
- Use rsync or Synology Snapshot Replication to sync volumes to standby NAS
- Only run one PDM instance at a time (no native HA support yet)

## High Availability

### PDM HA Status

PDM does **not** currently support native HA/clustering. Per the [roadmap](https://pve.proxmox.com/wiki/Proxmox_Datacenter_Manager_Roadmap):

> "evaluating if an active-standby like architecture for PDM makes sense"

### What PDM Enables

- Live migration of VMs between independent clusters
- Cross-datacenter migration for maintenance/failover
- Centralized management of multiple PVE HA clusters

### Workaround: Manual Failover

1. Replicate `pdm-config/` and `pdm-data/` to standby host
2. If primary fails, start PDM container on standby
3. PDM will have all remotes and config intact

## Access Points (Default Ports)

| Service | Port | URL |
|---------|------|-----|
| PDM Web UI | 8443 | https://localhost:8443 |
| PVE Web UI | 8006 | https://localhost:8006 |
| SSH | 22 | (mapped to 2222+) |

## Sources

- [Proxmox Datacenter Manager Overview](https://www.proxmox.com/en/products/proxmox-datacenter-manager/overview)
- [PDM Documentation](https://pdm.proxmox.com/docs/)
- [PDM Configuration Files](https://pdm.proxmox.com/docs/configuration-files.html)
- [PDM Roadmap](https://pve.proxmox.com/wiki/Proxmox_Datacenter_Manager_Roadmap)
- [GitHub: proxmox-datacenter-manager-docker](https://github.com/willmortimer/proxmox-datacenter-manager-docker)
- [Docker Hub: devzwf/proxmox-datacenter-manager](https://hub.docker.com/r/devzwf/proxmox-datacenter-manager)
