#!/bin/bash
# PVE Container Entrypoint
#
# Fixes for containerized PVE:
# 1. Sets up FQDN in /etc/hosts (required for node status)
# 2. Initializes local cluster on first boot (required for RRD data)
#
# References:
# - https://forum.proxmox.com/threads/node-seems-to-be-offline.102216/
# - https://chrichri.ween.de/o/b545ee3dc6664f0fbd581805c9cb3ebf

set -e

HOSTNAME=$(hostname)
CLUSTER_NAME="${HOSTNAME}cluster"
MARKER_FILE="/var/lib/pve-cluster/.initialized"

# Get primary IP (non-loopback)
get_primary_ip() {
    hostname -I | awk '{print $1}'
}

# Fix /etc/hosts with FQDN
# PVE requires hostname -f to return a domain for proper node status
fix_hosts_fqdn() {
    local ip=$(get_primary_ip)
    local domain="${DNS_DOMAIN:-local}"
    local fqdn="${HOSTNAME}.${domain}"

    if [ -n "$ip" ]; then
        # Check if already has FQDN
        if ! grep -q "$fqdn" /etc/hosts 2>/dev/null; then
            # Update or add the hosts entry with FQDN
            if grep -q "^${ip}[[:space:]]" /etc/hosts; then
                sed -i "s/^${ip}[[:space:]].*/${ip} ${fqdn} ${HOSTNAME}/" /etc/hosts
            else
                echo "${ip} ${fqdn} ${HOSTNAME}" >> /etc/hosts
            fi
            echo "Fixed /etc/hosts: ${ip} ${fqdn} ${HOSTNAME}"
        fi
    fi
}

# Initialize local cluster (required for RRD status data)
# Only runs on first boot - checks for marker file
init_local_cluster() {
    # Skip if already initialized
    if [ -f "$MARKER_FILE" ]; then
        return 0
    fi

    # Wait for pve-cluster to be ready
    local retries=30
    while [ $retries -gt 0 ]; do
        if [ -d /etc/pve ] && mountpoint -q /etc/pve 2>/dev/null; then
            break
        fi
        sleep 1
        retries=$((retries - 1))
    done

    # Skip if corosync.conf already exists (cluster already configured)
    if [ -f /etc/pve/corosync.conf ]; then
        touch "$MARKER_FILE"
        return 0
    fi

    local ip=$(get_primary_ip)
    if [ -n "$ip" ]; then
        echo "Initializing local cluster: $CLUSTER_NAME"
        # pvecm create requires pve-cluster to be running
        # This will be called from a background job after systemd starts
        (
            sleep 30  # Wait for services to start
            if [ ! -f /etc/pve/corosync.conf ]; then
                pvecm create "$CLUSTER_NAME" --link0 "$ip" 2>/dev/null || true
                touch "$MARKER_FILE"
                # Restart pvestatd to pick up the new cluster config
                systemctl restart pvestatd 2>/dev/null || true
            fi
        ) &
    fi
}

# Main
fix_hosts_fqdn

# Run cluster init in background (needs systemd running)
init_local_cluster

# Execute original entrypoint or command
exec "$@"
