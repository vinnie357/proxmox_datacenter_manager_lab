#!/usr/bin/env nu

# Reset all persistent data (volumes and directories)
# Requires confirmation before deleting

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))

    let volumes = [
        "pdm-data"
        "pbs-lib"
        "pbs-backups"
    ]

    let dirs = [
        "data/pve-1/iso"
        "data/pve-1/dump"
        "data/pve-2/iso"
        "data/pve-2/dump"
        "data/pve-3/iso"
        "data/pve-3/dump"
    ]

    print "This will delete all persistent data:"
    print ""
    print "Volumes:"
    for vol in $volumes {
        try {
            let existing = (^container volume list --format json | from json)
            if not ($existing | where Name == $vol | is-empty) {
                print $"  ($vol)"
            }
        } catch { }
    }

    print ""
    print "Directories:"
    for dir in $dirs {
        let path = $"($project_root)/($dir)"
        if ($path | path exists) {
            let count = (ls $path | length)
            print $"  ($dir)/ (($count) items)"
        }
    }

    print ""
    let confirm = (input "Are you sure you want to delete all data? [y/N] ")

    if ($confirm | str downcase) != "y" {
        print "Aborted."
        return
    }

    print ""
    print "Removing volumes..."
    for vol in $volumes {
        try {
            ^container volume rm $vol out+err> /dev/null
            print $"  Removed: ($vol)"
        } catch {
            print $"  Skipped: ($vol) (not found or in use)"
        }
    }

    print ""
    print "Cleaning directories..."
    for dir in $dirs {
        let path = $"($project_root)/($dir)"
        if ($path | path exists) {
            try {
                rm -rf ($path | path join "*")
                print $"  Cleaned: ($dir)/"
            } catch {
                print $"  Skipped: ($dir)/ (empty or error)"
            }
        }
    }

    print ""
    print "Data reset complete. Run 'mise setup' then 'mise start' to reinitialize."
}
