# Proxmox VE with fixes for containerized usage
#
# Based on: ghcr.io/longqt-sea/proxmox-ve
# Fixes:
#   - Adds rsyslog for Apple Container/Rosetta2 compatibility (no syslog socket)
#   - Adds rrdtool for node status graphs (missing from base image)
#   - Creates RRD directory structure
#
# Build:
#   docker build -t proxmox-ve .
#
# Or with Apple Container:
#   container build --tag proxmox-ve .

FROM ghcr.io/longqt-sea/proxmox-ve:latest

# Install rsyslog for Apple Container/Rosetta2 compatibility
# macOS containers don't provide /dev/log syslog socket, so we run our own
RUN apt-get update && \
    apt-get install -y --no-install-recommends rsyslog && \
    echo '*.* /dev/stdout' > /etc/rsyslog.d/50-stdout.conf

# Configure journald for container compatibility (Apple Container/Rosetta2)
# journald crashes with SIGTRAP due to unsupported syscalls, so we:
# - Set Storage=none to avoid filesystem operations
# - Forward everything to syslog (rsyslog handles it)
# - Disable audit to avoid kernel feature requirements
RUN mkdir -p /etc/systemd/journald.conf.d && \
    printf '[Journal]\nStorage=none\nForwardToSyslog=yes\nForwardToConsole=yes\nAudit=no\n' \
    > /etc/systemd/journald.conf.d/container.conf

# Install rrdtool for node status graphs
# The base image is missing this, causing "unknown" status in UI
RUN apt-get install -y --no-install-recommends rrdtool && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create RRD directory structure
RUN mkdir -p /var/lib/rrdcached/db/pve-node-9.0

# Labels
LABEL maintainer="Proxmox Lab"
LABEL org.opencontainers.image.description="Proxmox VE with rrdtool fix for containerized usage"
