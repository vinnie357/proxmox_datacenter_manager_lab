#!/usr/bin/env nu

# List exposed LXC services across all running PVE nodes
#
# Reads nginx stream config filenames from the ingress container
# to show which VMID/port combinations are currently exposed.
#
# Usage:
#   mise expose:list

def main [] {
    let ingress_vmid = 9000
    let nodes = ["pve-1" "pve-2" "pve-3"]
    mut found = false

    for node in $nodes {
        if not (is_running $node) {
            continue
        }

        # Check if ingress is running
        let ingress_status = try {
            ^container exec $node bash -c $"lxc-info -n ($ingress_vmid) -s -H 2>/dev/null" | str trim
        } catch {
            ""
        }

        if $ingress_status != "RUNNING" {
            continue
        }

        let ingress_pid = (^container exec $node bash -c $"lxc-info -n ($ingress_vmid) -p -H" | str trim)
        let node_ip = (^container exec $node hostname -I | str trim | split row " " | first)

        # List stream config files
        let files = try {
            ^container exec $node bash -c $"nsenter -t ($ingress_pid) -m -u -i -p -n -- ls /etc/nginx/stream.d/ 2>/dev/null" | str trim
        } catch {
            ""
        }

        if ($files | is-empty) {
            continue
        }

        let conf_files = ($files | lines | where { |f| $f ends-with ".conf" })
        if ($conf_files | is-empty) {
            continue
        }

        if not $found {
            print "Exposed LXC Services:"
            print ""
            $found = true
        }

        print $"  ($node) \(($node_ip)\):"

        for f in $conf_files {
            # Parse filename: {vmid}-{port}.conf
            let name = ($f | str replace ".conf" "")
            let parts = ($name | split row "-")
            if ($parts | length) >= 2 {
                let vmid = ($parts | first)
                let port = ($parts | last)

                # Read the config to get target IP
                let conf_content = try {
                    ^container exec $node bash -c $"nsenter -t ($ingress_pid) -m -u -i -p -n -- cat /etc/nginx/stream.d/($f)" | str trim
                } catch {
                    ""
                }

                # Find host-port from iptables rules
                let host_port = try {
                    let rule = (^container exec $node bash -c $"iptables -t nat -S PREROUTING 2>/dev/null | grep 'ingress-($vmid)-($port)'" | str trim)
                    # Extract --dport value
                    let dport_parts = ($rule | split row "--dport " | last | split row " " | first)
                    $dport_parts
                } catch {
                    $port
                }

                print $"    VMID ($vmid) port ($port) -> http://($node_ip):($host_port)"
            }
        }
        print ""
    }

    if not $found {
        print "No exposed services found."
        print "Use: mise expose -- --node <node> --vmid <vmid> --port <port>"
    }
}

def is_running [name: string] {
    try {
        let list = (^container list --format json | from json)
        $list | any { |c| $c.configuration.id == $name and $c.status == "running" }
    } catch {
        false
    }
}
