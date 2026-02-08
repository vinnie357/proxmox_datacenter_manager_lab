#!/usr/bin/env nu

# Expose an LXC container's port through the ingress proxy
#
# Adds an nginx stream proxy config and iptables DNAT rule so the LXC
# service is reachable from the macOS host via the PVE node's IP.
#
# Usage:
#   mise expose -- --node pve-1 --vmid 100 --port 80
#   mise expose -- --node pve-1 --vmid 100 --port 80 --host-port 9080

def main [
    --node: string    # PVE node (required)
    --vmid: int       # Target LXC VMID (required)
    --port: int       # Target port inside the LXC (required)
    --host-port: int  # Port on the PVE node's external IP (default: same as --port)
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

    let host_port = if $host_port == null or $host_port == 0 { $port } else { $host_port }
    let ingress_vmid = 9000

    # Verify node is running
    if not (is_running $node) {
        print $"ERROR: ($node) is not running"
        exit 1
    }

    # Verify ingress is running
    let ingress_status = try {
        ^container exec $node bash -c $"lxc-info -n ($ingress_vmid) -s -H 2>/dev/null" | str trim
    } catch {
        ""
    }
    if $ingress_status != "RUNNING" {
        print $"ERROR: Ingress container not running on ($node). Run: mise ingress -- --node ($node)"
        exit 1
    }

    # Get target LXC IP from pct config
    let target_ip = get_lxc_ip $node $vmid
    if ($target_ip | is-empty) {
        print $"ERROR: Could not determine IP for VMID ($vmid) on ($node)"
        exit 1
    }

    print $"Exposing ($node)/($vmid) port ($port) -> host port ($host_port)"
    print $"  Target: ($target_ip):($port)"

    # Get ingress PID for nsenter
    let ingress_pid = (^container exec $node bash -c $"lxc-info -n ($ingress_vmid) -p -H" | str trim)

    # Write nginx stream config
    let stream_conf = $"# ($vmid)-($port): forward to ($target_ip):($port)\nserver {\n    listen ($port);\n    proxy_pass ($target_ip):($port);\n}\n"
    let conf_file = $"/etc/nginx/stream.d/($vmid)-($port).conf"

    ^container exec $node bash -c $"nsenter -t ($ingress_pid) -m -u -i -p -n -- sh -c 'cat > ($conf_file) << '\"'\"'STREAMEOF'\"'\"'\n($stream_conf)\nSTREAMEOF'" out+err> /dev/null
    print $"  nginx stream config written: ($conf_file)"

    # Reload nginx
    ^container exec $node bash -c $"nsenter -t ($ingress_pid) -m -u -i -p -n -- nginx -s reload" out+err> /dev/null
    print "  nginx reloaded"

    # Add iptables DNAT rule (skip if already exists)
    let comment = $"ingress-($vmid)-($port)"
    let rule_exists = try {
        (^container exec $node bash -c $"iptables -t nat -C PREROUTING -i eth0 -p tcp --dport ($host_port) -j DNAT --to-destination 172.16.99.2:($port) -m comment --comment ($comment) 2>/dev/null" | complete).exit_code == 0
    } catch {
        false
    }

    if not $rule_exists {
        ^container exec $node bash -c $"iptables -t nat -A PREROUTING -i eth0 -p tcp --dport ($host_port) -j DNAT --to-destination 172.16.99.2:($port) -m comment --comment ($comment)" out+err> /dev/null
        print $"  iptables DNAT rule added: ($host_port) -> 172.16.99.2:($port)"
    } else {
        print "  iptables DNAT rule already exists"
    }

    # Get PVE node IP for access URL
    let node_ip = (^container exec $node hostname -I | str trim | split row " " | first)
    print ""
    print $"Access: http://($node_ip):($host_port)"
}

def is_running [name: string] {
    try {
        let list = (^container list --format json | from json)
        $list | any { |c| $c.configuration.id == $name and $c.status == "running" }
    } catch {
        false
    }
}

def get_lxc_ip [node: string, vmid: int] {
    try {
        let config = (^container exec $node bash -c $"pct config ($vmid)" | str trim)
        let net_line = ($config | lines | where { |l| $l starts-with "net0:" } | first)
        # Parse ip=X.X.X.X/Y from net0 line
        let parts = ($net_line | split row "," | where { |p| ($p | str trim) starts-with "ip=" } | first)
        let ip_cidr = ($parts | str trim | str replace "ip=" "")
        $ip_cidr | split row "/" | first
    } catch {
        ""
    }
}
