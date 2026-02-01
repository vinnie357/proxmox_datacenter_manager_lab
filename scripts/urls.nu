#!/usr/bin/env nu

# Display access URLs for the Proxmox lab

def main [] {
    # Check for DNS domain
    let dns_domain = try {
        let dns_list = (^container system dns ls | lines | skip 1 | first)
        $dns_list | str trim
    } catch {
        ""
    }

    print "Proxmox Datacenter Manager Lab"
    print "==============================="
    print ""

    print "Access URLs (localhost):"
    print ""
    print "  PDM:   https://localhost:8443"
    print "  PVE-1: https://localhost:8006  (SSH: ssh -p 2222 root@localhost)"
    print "  PVE-2: https://localhost:8007  (SSH: ssh -p 2223 root@localhost)"
    print "  PVE-3: https://localhost:8008  (SSH: ssh -p 2224 root@localhost)"

    if ($dns_domain | is-not-empty) {
        print ""
        print $"DNS Hostnames (($dns_domain)):"
        print ""
        print $"  PDM:   https://pdm.($dns_domain):8443"
        print $"  PVE-1: https://pve-1.($dns_domain):8006"
        print $"  PVE-2: https://pve-2.($dns_domain):8007"
        print $"  PVE-3: https://pve-3.($dns_domain):8008"
    }

    print ""
    print "Default credentials: root / root"
    print ""

    print "Container Status:"
    ^container list
}
