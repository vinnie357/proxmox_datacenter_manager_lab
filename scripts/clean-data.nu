#!/usr/bin/env nu

# Reset all persistent data directories
# Requires confirmation before deleting

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))

    let dirs = [
        "data/pdm-config"
        "data/pdm-data"
        "data/backups"
        "data/iso"
        "data/pve-1/dump"
        "data/pve-2/dump"
        "data/pve-3/dump"
        "data/pbs-config"
        "data/pbs-lib"
        "data/pbs-logs"
        "data/pbs-backups"
    ]

    print "This will delete all persistent data:"
    for dir in $dirs {
        let path = $"($project_root)/($dir)"
        if ($path | path exists) {
            let count = (ls $path | length)
            if $count > 0 {
                print $"  ($dir)/ (($count) items)"
            }
        }
    }

    print ""
    let confirm = (input "Are you sure you want to delete all data? [y/N] ")

    if ($confirm | str downcase) != "y" {
        print "Aborted."
        return
    }

    print ""
    print "Cleaning data directories..."

    for dir in $dirs {
        let path = $"($project_root)/($dir)"
        if ($path | path exists) {
            # Remove contents but keep the directory
            try {
                rm -rf $"($path)/*"
                print $"  Cleaned: ($dir)/"
            } catch {
                # Directory might be empty
                print $"  Skipped: ($dir)/ (empty)"
            }
        }
    }

    print ""
    print "Data reset complete. Run 'mise start' to reinitialize containers."
}
