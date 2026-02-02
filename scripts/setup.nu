#!/usr/bin/env nu

# Setup script for Proxmox Datacenter Manager Lab
# Uses Apple Container on macOS 26+ (Tahoe)

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))

    print "Setting up Proxmox Datacenter Manager Lab..."
    print $"Project root: ($project_root)"

    # Check for Apple container command
    print ""
    print "Checking Apple Container..."

    let container_exists = (which container | length) > 0
    if not $container_exists {
        print "  ERROR: 'container' command not found."
        print "  Apple Container requires macOS 26+ (Tahoe)"
        exit 1
    }

    # Start container system if needed
    print "  Starting container system..."
    try {
        ^container system start
        print "  Container system ready"
    } catch {
        print "  WARNING: Could not start container system"
    }

    # Create named volumes for persistent storage (services need specific ownership)
    print ""
    print "Creating volumes..."
    let volumes = [
        "pdm-data"
        "pbs-lib"
        "pbs-backups"
    ]

    for vol in $volumes {
        try {
            let existing = (^container volume list --format json | from json)
            if ($existing | where Name == $vol | is-empty) {
                ^container volume create $vol out+err> /dev/null
                print $"  Created volume: ($vol)"
            } else {
                print $"  Exists volume:  ($vol)"
            }
        } catch {
            print $"  WARNING: Could not create volume ($vol)"
        }
    }

    # Create local directories for PVE storage (bind mounts - easier to access)
    print ""
    print "Creating local directories..."
    let dirs = [
        "data/backups"
        "data/pve-1/iso"
        "data/pve-1/dump"
        "data/pve-2/iso"
        "data/pve-2/dump"
        "data/pve-3/iso"
        "data/pve-3/dump"
    ]
    for dir in $dirs {
        let path = $"($project_root)/($dir)"
        if not ($path | path exists) {
            mkdir $path
            print $"  Created: ($dir)/"
        } else {
            print $"  Exists:  ($dir)/"
        }
    }

    # Test x86_64 emulation
    print ""
    print "Testing x86_64 emulation (Rosetta)..."
    try {
        let result = (^container run --rm --platform linux/amd64 alpine uname -m | complete)
        if $result.exit_code == 0 and ($result.stdout | str trim) == "x86_64" {
            print "  x86_64 emulation working"
        } else {
            print "  WARNING: x86_64 emulation may not work correctly"
        }
    } catch {
        print "  WARNING: Could not test x86_64 emulation"
    }

    print ""
    print "Setup complete! Run 'mise start' to launch the lab."
}
