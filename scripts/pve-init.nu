#!/usr/bin/env nu

# Initialize PVE nodes for containerized usage
#
# Fixes required for containerized PVE:
# 1. Sets up FQDN in /etc/hosts (required for node status)
# 2. Initializes local cluster on first boot (required for RRD data)
#
# References:
# - https://forum.proxmox.com/threads/node-seems-to-be-offline.102216/
# - https://chrichri.ween.de/o/b545ee3dc6664f0fbd581805c9cb3ebf

def main [] {
    let dns_domain = get_dns_domain

    for node in ["pve-1" "pve-2" "pve-3"] {
        if (is_running $node) {
            print $"Initializing ($node)..."
            init_pve_node $node $dns_domain
        }
    }
}

def get_dns_domain [] {
    try {
        let dns_list = (^container system dns ls | lines | skip 1 | first)
        $dns_list | str trim
    } catch {
        "local"
    }
}

def is_running [name: string] {
    try {
        let list = (^container list --format json | from json)
        $list | any { |c| $c.configuration.id == $name and $c.status == "running" }
    } catch {
        false
    }
}

def init_pve_node [name: string, dns_domain: string] {
    # Fix /etc/hosts with FQDN
    # PVE requires hostname -f to return a domain for proper node status
    fix_hosts_fqdn $name $dns_domain

    # Initialize local cluster if not already done
    # Required for RRD status data to be written
    init_local_cluster $name
}

def fix_hosts_fqdn [name: string, dns_domain: string] {
    try {
        # Get primary IP
        let ip = (^container exec $name hostname -I | str trim | split row " " | first)
        let fqdn = $"($name).($dns_domain)"

        # Check if FQDN already in hosts
        let hosts = (^container exec $name cat /etc/hosts | complete)
        if ($hosts.stdout | str contains $fqdn) {
            print $"  ($name) FQDN already configured"
            return
        }

        # Update /etc/hosts with FQDN
        let hosts_entry = $"($ip) ($fqdn) ($name)"
        ^container exec $name bash -c $"
            if grep -q '^($ip)[[:space:]]' /etc/hosts; then
                sed -i 's/^($ip)[[:space:]].*$/($ip) ($fqdn) ($name)/' /etc/hosts
            else
                echo '($hosts_entry)' >> /etc/hosts
            fi
        " out+err> /dev/null
        print $"  ($name) FQDN fixed: ($hosts_entry)"
    } catch { |e|
        print $"  ($name) FQDN fix failed: ($e)"
    }
}

def init_local_cluster [name: string] {
    try {
        # Check if corosync.conf already exists (cluster already configured)
        let check = (^container exec $name test -f /etc/pve/corosync.conf | complete)
        if $check.exit_code == 0 {
            print $"  ($name) cluster already initialized"
            # Restart pvestatd to ensure it picks up cluster config
            ^container exec $name systemctl restart pvestatd out+err> /dev/null
            return
        }

        # Get primary IP for cluster link
        let ip = (^container exec $name hostname -I | str trim | split row " " | first)
        let cluster_name = $"($name)cluster"

        print $"  ($name) initializing cluster: ($cluster_name)"
        ^container exec $name pvecm create $cluster_name --link0 $ip out+err> /dev/null

        # Restart pvestatd to pick up new cluster config
        ^container exec $name systemctl restart pvestatd out+err> /dev/null
        print $"  ($name) cluster initialized"
    } catch { |e|
        print $"  ($name) cluster init failed: ($e)"
    }
}
