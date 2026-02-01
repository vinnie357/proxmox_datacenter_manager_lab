#!/usr/bin/env nu

# Setup script for Proxmox Datacenter Manager Lab
# Uses Apple Container on macOS 26+ (Tahoe)

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))

    print "Setting up Proxmox Datacenter Manager Lab..."
    print $"Project root: ($project_root)"

    # Create data directories
    let dirs = [
        "data/pdm-config"
        "data/pdm-data"
        "data/VM-Backup"
        "data/ISOs"
        "data/backups"
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
