#!/usr/bin/env nu

# Stop and remove all Proxmox lab containers

def main [] {
    print "Cleaning up Proxmox lab..."

    let containers = ["pdm" "pve-1" "pve-2" "pve-3" "pbs"]

    for name in $containers {
        try {
            ^container stop $name
            print $"  Stopped ($name)"
        } catch { }

        try {
            ^container rm $name
            print $"  Removed ($name)"
        } catch { }
    }

    print ""
    print "Cleanup complete."
    print "Note: Data in data/ is preserved."
}
