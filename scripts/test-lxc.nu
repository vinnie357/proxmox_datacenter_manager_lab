#!/usr/bin/env nu

# Test LXC container creation on a PVE node
#
# Downloads the Alpine LXC template, creates a container, starts it,
# verifies it's running, then cleans up.

def main [
    --node: string = "pve-1"  # PVE node to test on
    --keep                     # Keep the container after test (don't destroy)
] {
    let vmid = 100
    let template = "alpine-3.23-default_20260116_amd64.tar.xz"

    print $"=== Testing LXC on ($node) ==="
    print ""

    # Verify the node is running
    print $"Checking ($node) is running..."
    let running = try {
        let list = (^container list --format json | from json)
        $list | any { |c| $c.configuration.id == $node and $c.status == "running" }
    } catch {
        false
    }
    if not $running {
        print $"ERROR: ($node) is not running. Start with: mise start"
        exit 1
    }
    print $"  ($node) is running"

    # Download template if needed
    print ""
    print "Downloading Alpine LXC template..."
    let template_exists = (^container exec $node bash -c $"test -f /var/lib/vz/template/cache/($template) && echo yes || echo no" | str trim) == "yes"
    if $template_exists {
        print "  Template already cached"
    } else {
        ^container exec $node bash -c "pveam update" out+err> /dev/null
        print "  Downloading..."
        ^container exec $node bash -c $"pveam download local ($template)" out+err> /dev/null
        print $"  Downloaded ($template)"
    }

    # Destroy existing container if present
    try {
        ^container exec $node bash -c $"pct stop ($vmid)" out+err> /dev/null
    } catch { }
    try {
        ^container exec $node bash -c $"pct destroy ($vmid) --purge" out+err> /dev/null
    } catch { }

    # Create container (no networking - vmbr0 unavailable in nested containers)
    print ""
    print $"Creating LXC container ($vmid)..."
    ^container exec $node bash -c $"pct create ($vmid) local:vztmpl/($template) --hostname test-ct --memory 128 --rootfs local:0.5" out+err> /dev/null
    print "  Created"

    # Start container
    print $"Starting LXC container ($vmid)..."
    ^container exec $node bash -c $"pct start ($vmid)" out+err> /dev/null
    print "  Started"

    # Verify it's running
    print ""
    print "Verifying container..."
    let status = (^container exec $node bash -c $"lxc-info -n ($vmid) -s -H" | str trim)
    if $status != "RUNNING" {
        print $"  ERROR: Container status is ($status), expected RUNNING"
        exit 1
    }
    print $"  Status: ($status)"

    # Read Alpine release using nsenter (pct exec fails under Rosetta 2)
    let pid = (^container exec $node bash -c $"lxc-info -n ($vmid) -p -H" | str trim)
    let release = (^container exec $node bash -c $"nsenter -t ($pid) -m -u -i -p -- cat /etc/alpine-release" | str trim)
    print $"  Alpine release: ($release)"

    let hostname = (^container exec $node bash -c $"nsenter -t ($pid) -m -u -i -p -- hostname" | str trim)
    print $"  Hostname: ($hostname)"

    # Cleanup
    if not $keep {
        print ""
        print "Cleaning up..."
        ^container exec $node bash -c $"pct stop ($vmid)" out+err> /dev/null
        ^container exec $node bash -c $"pct destroy ($vmid) --purge" out+err> /dev/null
        print $"  Destroyed container ($vmid)"
    } else {
        print ""
        print $"Container ($vmid) kept running on ($node)"
        print $"  Enter with: mise shell:pve1 then nsenter -t ($pid) -m -u -i -p -- /bin/sh"
    }

    print ""
    print "=== LXC test passed ==="
}
