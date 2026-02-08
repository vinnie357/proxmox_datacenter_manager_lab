#!/usr/bin/env nu

# Remove an exposed LXC container port from the ingress proxy
#
# Removes the nginx stream config and iptables DNAT rule.
#
# Usage:
#   mise unexpose -- --node pve-1 --vmid 100 --port 80

def main [
    --node: string    # PVE node (required)
    --vmid: int       # Target LXC VMID (required)
    --port: int       # Port to unexpose (required)
] {
    if ($node | is-empty) {
        print "ERROR: --node is required"
        exit 1
    }
    if $vmid == null or $vmid == 0 {
        print "ERROR: --vmid is required"
        exit 1
    }
    if $port == null or $port == 0 {
        print "ERROR: --port is required"
        exit 1
    }

    let ingress_vmid = 9000

    # Verify node is running
    if not (is_running $node) {
        print $"ERROR: ($node) is not running"
        exit 1
    }

    print $"Unexposing ($node)/($vmid) port ($port)"

    # Check if ingress is running
    let ingress_status = try {
        ^container exec $node bash -c $"lxc-info -n ($ingress_vmid) -s -H 2>/dev/null" | str trim
    } catch {
        ""
    }

    if $ingress_status == "RUNNING" {
        let ingress_pid = (^container exec $node bash -c $"lxc-info -n ($ingress_vmid) -p -H" | str trim)

        # Remove nginx stream config
        let conf_file = $"/etc/nginx/stream.d/($vmid)-($port).conf"
        ^container exec $node bash -c $"nsenter -t ($ingress_pid) -m -u -i -p -n -- rm -f ($conf_file)" out+err> /dev/null
        print $"  Removed ($conf_file)"

        # Reload nginx
        ^container exec $node bash -c $"nsenter -t ($ingress_pid) -m -u -i -p -n -- nginx -s reload" out+err> /dev/null
        print "  nginx reloaded"
    } else {
        print "  Ingress not running, skipping nginx cleanup"
    }

    # Remove iptables DNAT rules matching the comment
    let comment = $"ingress-($vmid)-($port)"
    remove_iptables_rules $node $comment

    print ""
    print $"Unexposed ($vmid) port ($port) on ($node)"
}

def is_running [name: string] {
    try {
        let list = (^container list --format json | from json)
        $list | any { |c| $c.configuration.id == $name and $c.status == "running" }
    } catch {
        false
    }
}

def remove_iptables_rules [node: string, comment: string] {
    # List nat PREROUTING rules and remove those matching our comment
    # Loop because -D only removes one rule at a time
    loop {
        let result = (^container exec $node bash -c $"iptables -t nat -S PREROUTING 2>/dev/null | grep -m1 '($comment)'" | complete)
        if $result.exit_code != 0 {
            break
        }
        # The -S output is like: -A PREROUTING ... , convert -A to -D to delete
        let rule = ($result.stdout | str trim | str replace "-A " "-D ")
        ^container exec $node bash -c $"iptables -t nat ($rule)" out+err> /dev/null
        print $"  Removed iptables rule: ($comment)"
    }
}
