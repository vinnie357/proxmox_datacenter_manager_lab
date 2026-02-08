#!/usr/bin/env nu

# View container logs
# Usage: logs.nu [container] [--follow] [--lines N]

def main [
    container?: string  # Container name (pdm, pve-1, pve-2, pve-3, pbs). Default: all
    --follow (-f)       # Follow log output
    --lines (-n): int = 50  # Number of lines to show
] {
    let containers = if ($container | is-empty) {
        ["pdm" "pve-1" "pve-2" "pve-3" "pbs"]
    } else {
        [$container]
    }

    for name in $containers {
        if ($containers | length) > 1 {
            print $"=== ($name) ==="
        }

        match $name {
            "pdm" => { show_pdm_logs $follow $lines }
            "pve-1" | "pve-2" | "pve-3" => { show_pve_logs $name $follow $lines }
            "pbs" => { show_pbs_logs $follow $lines }
            _ => { print $"Unknown container: ($name)" }
        }

        if ($containers | length) > 1 {
            print ""
        }
    }
}

def show_pdm_logs [follow: bool, lines: int] {
    # PDM uses journalctl for service logs
    try {
        if $follow {
            ^container exec pdm journalctl -n $lines -f
        } else {
            let output = (^container exec pdm journalctl -n $lines --no-pager | complete)
            if ($output.stdout | str trim) == "-- No entries --" or ($output.stdout | is-empty) {
                # Fall back to API logs
                print "Service logs empty, showing API access log:"
                ^container exec pdm tail -n $lines /var/log/proxmox-datacenter-manager/api/access.log
            } else {
                print $output.stdout
            }
        }
    } catch {
        print "Could not retrieve PDM logs"
    }
}

def show_pve_logs [name: string, follow: bool, lines: int] {
    try {
        if $follow {
            ^container exec $name journalctl -n $lines -f
        } else {
            let output = (^container exec $name journalctl -n $lines --no-pager | complete)
            if ($output.stdout | str trim) == "-- No entries --" or ($output.stdout | is-empty) {
                # Fall back to pveproxy logs
                print "Service logs empty, showing pveproxy status:"
                ^container exec $name systemctl status pveproxy --no-pager
            } else {
                print $output.stdout
            }
        }
    } catch {
        print $"Could not retrieve ($name) logs"
    }
}

def show_pbs_logs [follow: bool, lines: int] {
    try {
        # PBS uses runit, check /var/log/proxmox-backup
        if $follow {
            ^container exec pbs tail -f /var/log/proxmox-backup/api/access.log
        } else {
            print "=== PBS API Access Log ==="
            ^container exec pbs tail -n $lines /var/log/proxmox-backup/api/access.log
            print ""
            print "=== PBS Auth Log ==="
            ^container exec pbs tail -n 10 /var/log/proxmox-backup/api/auth.log
        }
    } catch {
        print "Could not retrieve PBS logs"
    }
}
