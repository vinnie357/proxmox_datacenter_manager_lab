#!/usr/bin/env nu

# Download minimal test images for Proxmox lab
#
# Sources:
# - Tiny Core Linux: http://tinycorelinux.net/
#   Smallest practical Linux ISO at ~24MB, works in nested virtualization
#   Reference: https://enterpriseadmins.org/blog/lab-infrastructure/lightweight-vm-for-testing-tinycore-linux/
#
# - Alpine Linux LXC: https://alpinelinux.org/
#   Smallest LXC template at ~3-4MB compressed (~10MB installed)
#   Uses musl libc + BusyBox for minimal footprint
#   Reference: https://nelsonslog.wordpress.com/2023/12/14/proxmox-linux-container-sizes-alpine-etc/

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))
    let iso_filename = "TinyCorePure64-15.0.iso"
    let expected_md5 = "11e9b4ce52825d9d221515e90e5ac1c3"

    # Source cache directory and per-node ISO directories
    let cache_dir = $"($project_root)/data/iso"
    let pve_dirs = [
        $"($project_root)/data/pve-1/iso"
        $"($project_root)/data/pve-2/iso"
        $"($project_root)/data/pve-3/iso"
    ]

    # Ensure all directories exist
    for dir in ([$cache_dir] | append $pve_dirs) {
        if not ($dir | path exists) {
            mkdir $dir
            print $"Created: ($dir)"
        }
    }

    print "=== Downloading Test Images for Proxmox Lab ==="
    print ""

    let cache_path = $"($cache_dir)/($iso_filename)"

    # Check if cached file exists and has correct hash
    let needs_download = if ($cache_path | path exists) {
        let current_md5 = (open $cache_path | hash md5)
        if $current_md5 == $expected_md5 {
            let size = (ls $cache_path | get size.0)
            print $"Tiny Core Linux ISO already cached with correct hash \(($size)\)"
            false
        } else {
            print "Cached ISO has incorrect hash, re-downloading..."
            true
        }
    } else {
        true
    }

    if $needs_download {
        print "Source: http://tinycorelinux.net/"
        print "Downloading Tiny Core Linux ISO (~24MB)..."

        http get "http://tinycorelinux.net/15.x/x86_64/release/TinyCorePure64-15.0.iso"
            | save -f $cache_path

        # Verify downloaded file
        let downloaded_md5 = (open $cache_path | hash md5)
        if $downloaded_md5 != $expected_md5 {
            print $"ERROR: Downloaded file hash \(($downloaded_md5)\) does not match expected \(($expected_md5)\)"
            rm $cache_path
            exit 1
        }

        let size = (ls $cache_path | get size.0)
        print $"Done! ISO cached to data/iso/($iso_filename) \(($size)\)"
    }

    # Copy to each PVE node's ISO directory
    print ""
    print "Copying ISO to PVE nodes..."
    for pve_dir in $pve_dirs {
        let dest_path = $"($pve_dir)/($iso_filename)"
        let node_name = ($pve_dir | path basename | path dirname | path basename)

        # Check if destination needs updating
        let needs_copy = if ($dest_path | path exists) {
            let dest_md5 = (open $dest_path | hash md5)
            $dest_md5 != $expected_md5
        } else {
            true
        }

        if $needs_copy {
            cp $cache_path $dest_path
            let relative_path = ($pve_dir | str replace $"($project_root)/" "")
            print $"  Copied to ($relative_path)/($iso_filename)"
        } else {
            let relative_path = ($pve_dir | str replace $"($project_root)/" "")
            print $"  Already exists: ($relative_path)/($iso_filename)"
        }
    }
    print ""
    print "=== LXC Template Instructions ==="
    print "Alpine Linux is the smallest LXC template (~3-4MB compressed)"
    print "Source: https://images.linuxcontainers.org/"
    print ""
    print "Run inside a PVE container to download:"
    print "  pveam update"
    print "  pveam available | grep alpine"
    print "  pveam download local alpine-3.23-default_20260116_amd64.tar.xz"
}
