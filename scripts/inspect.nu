#!/usr/bin/env nu

# Inspect PDM container storage paths

def main [] {
    print "Inspecting PDM container storage paths..."
    print ""

    # Check if PDM is running
    let running = try {
        let list = (^container list --format json | from json)
        $list | any { |c| $c.ID == "pdm" }
    } catch {
        false
    }

    if not $running {
        print "PDM container is not running."
        print "Start with: mise start"
        exit 1
    }

    print "=== /etc/proxmox-datacenter-manager/ ==="
    try {
        ^container exec pdm ls -la /etc/proxmox-datacenter-manager/
    } catch {
        print "  (directory does not exist or is empty)"
    }

    print ""
    print "=== /var/lib/proxmox-datacenter-manager/ ==="
    try {
        ^container exec pdm ls -la /var/lib/proxmox-datacenter-manager/
    } catch {
        print "  (directory does not exist or is empty)"
    }

    print ""
    print "=== Service Status ==="
    try {
        ^container exec pdm systemctl status proxmox-datacenter-api.service --no-pager
    } catch {
        print "  (could not check service status)"
    }
}
