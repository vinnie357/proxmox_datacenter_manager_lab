#!/usr/bin/env nu

# Stop the Proxmox lab

def main [] {
    print "Stopping Proxmox lab..."

    let containers = ["pdm" "pve-1" "pve-2" "pve-3"]

    for name in $containers {
        try {
            ^container stop $name
            print $"  Stopped ($name)"
        } catch {
            # Container might not be running
        }
    }

    print "Lab stopped."
}
