# Apple Container Commands (macOS 26+)

Minimal commands for running Proxmox containers on macOS Tahoe using Apple's native containerization with Rosetta 2.

## Prerequisites

```bash
container system start
```

## Required Flags

| Flag | Purpose |
|------|---------|
| `--platform linux/amd64` | x86_64 image |
| `--rosetta` | Rosetta 2 emulation |
| `--virtualization` | **Required** for systemd |

## PDM (Datacenter Manager)

```bash
container run -d \
  --name pdm \
  --platform linux/amd64 \
  --rosetta \
  --virtualization \
  -p 8443:8443 \
  ghcr.io/longqt-sea/proxmox-datacenter-manager
```

## PVE (Proxmox VE Node)

```bash
container run -d \
  --name pve-1 \
  --platform linux/amd64 \
  --rosetta \
  --virtualization \
  -p 8006:8006 \
  ghcr.io/longqt-sea/proxmox-ve
```

## Management

```bash
container list              # List running
container stop pdm          # Stop
container rm pdm            # Remove
container logs pdm          # Logs
container exec pdm ps aux   # Run command
```

## Access

- PDM: https://localhost:8443
- PVE: https://localhost:8006

---

**For Linux/Windows:** See `examples/docker-compose/docker-compose.yml`
