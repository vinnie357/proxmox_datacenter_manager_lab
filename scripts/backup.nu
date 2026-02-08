#!/usr/bin/env nu

# Backup script for PDM config and data
# Copies data from running container (volume mounts not used with Apple Container)

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))
    let timestamp = (date now | format date "%Y%m%d_%H%M%S")
    let backup_dir = $"($project_root)/data/backups/($timestamp)"

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

    print $"Creating backup: ($backup_dir)"
    mkdir $backup_dir

    # Backup pdm config from container
    print "  Backing up /etc/proxmox-datacenter-manager/..."
    try {
        ^container exec pdm tar -czf - -C /etc proxmox-datacenter-manager
        | save $"($backup_dir)/pdm-config.tar.gz"
        print "    Saved pdm-config.tar.gz"
    } catch {
        print "    (no config to backup or failed)"
    }

    # Backup pdm data from container
    print "  Backing up /var/lib/proxmox-datacenter-manager/..."
    try {
        ^container exec pdm tar -czf - -C /var/lib proxmox-datacenter-manager
        | save $"($backup_dir)/pdm-data.tar.gz"
        print "    Saved pdm-data.tar.gz"
    } catch {
        print "    (no data to backup or failed)"
    }

    # Create backup manifest
    let manifest = {
        timestamp: $timestamp
        created: (date now | format date "%Y-%m-%d %H:%M:%S")
        runtime: "Apple Container (macOS 26+)"
        method: "container exec tar"
    }

    $manifest | to json | save $"($backup_dir)/manifest.json"

    print ""
    print "Backup complete:"
    ls $backup_dir | select name size | print

    # Show recent backups
    print ""
    print "Recent backups:"
    ls $"($project_root)/data/backups"
    | where type == dir
    | sort-by modified
    | reverse
    | first 5
    | select name modified
    | print
}
