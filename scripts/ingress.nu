#!/usr/bin/env nu

# Create an ingress LXC container on PVE nodes
#
# The ingress container runs nginx in stream mode to proxy traffic from
# the PVE node's routable IP (192.168.64.x) to LXC containers on the
# internal vmbr1 bridge (172.16.99.0/24).
#
# Architecture:
#   macOS -> pve-1 (192.168.64.x:port) -> iptables DNAT -> ingress (172.16.99.2:port) -> nginx stream -> target LXC
#
# Usage:
#   mise ingress                     # all running PVE nodes
#   mise ingress -- --node pve-1     # specific node

def main [
    --node: string  # PVE node to create ingress on (default: all running nodes)
] {
    let nodes = if ($node | is-not-empty) {
        [$node]
    } else {
        ["pve-1" "pve-2" "pve-3"]
    }

    let vmid = 9000
    let template = "alpine-3.23-default_20260116_amd64.tar.xz"

    for n in $nodes {
        if not (is_running $n) {
            print $"Skipping ($n) \(not running\)"
            continue
        }

        create_ingress $n $vmid $template
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

def create_ingress [node: string, vmid: int, template: string] {
    print $"=== Creating ingress on ($node) ==="

    # Check if already running
    let status = try {
        ^container exec $node bash -c $"lxc-info -n ($vmid) -s -H 2>/dev/null" | str trim
    } catch {
        ""
    }
    if $status == "RUNNING" {
        print $"  Ingress \(VMID ($vmid)\) already running on ($node)"
        return
    }

    # Download template if needed
    print "  Downloading Alpine template..."
    let template_exists = (^container exec $node bash -c $"test -f /var/lib/vz/template/cache/($template) && echo yes || echo no" | str trim) == "yes"
    if $template_exists {
        print "    Template already cached"
    } else {
        ^container exec $node bash -c "pveam update" out+err> /dev/null
        ^container exec $node bash -c $"pveam download local ($template)" out+err> /dev/null
        print $"    Downloaded ($template)"
    }

    # Destroy any stopped ingress container
    try { ^container exec $node bash -c $"pct stop ($vmid)" out+err> /dev/null } catch { }
    try { ^container exec $node bash -c $"pct destroy ($vmid) --purge" out+err> /dev/null } catch { }

    # Create ingress container on vmbr1
    print $"  Creating LXC ($vmid)..."
    ^container exec $node bash -c $"pct create ($vmid) local:vztmpl/($template) --hostname ingress --memory 64 --rootfs local:0.5 --net0 name=eth0,bridge=vmbr1,ip=172.16.99.2/24,gw=172.16.99.1 --nameserver 8.8.8.8"  out+err> /dev/null
    print "    Created"

    # Start container
    print $"  Starting LXC ($vmid)..."
    ^container exec $node bash -c $"pct start ($vmid)" out+err> /dev/null
    print "    Started"

    # Wait for container to be ready
    sleep 2sec

    # Get PID for nsenter
    let pid = (^container exec $node bash -c $"lxc-info -n ($vmid) -p -H" | str trim)

    # Install nginx
    print "  Installing nginx..."
    ^container exec $node bash -c $"nsenter -t ($pid) -m -u -i -p -n -- apk add --no-cache nginx nginx-mod-stream" out+err> /dev/null
    print "    nginx installed"

    # Write nginx.conf with stream module
    print "  Configuring nginx..."
    let nginx_conf = "
load_module /usr/lib/nginx/modules/ngx_stream_module.so;

pid /tmp/nginx.pid;
worker_processes auto;

events {
    worker_connections 512;
}

stream {
    include /etc/nginx/stream.d/*.conf;
}
"
    ^container exec $node bash -c $"nsenter -t ($pid) -m -u -i -p -n -- sh -c 'mkdir -p /etc/nginx/stream.d && cat > /etc/nginx/nginx.conf << '\"'\"'NGINXEOF'\"'\"'\n($nginx_conf)\nNGINXEOF'" out+err> /dev/null
    print "    nginx configured"

    # Start nginx
    print "  Starting nginx..."
    ^container exec $node bash -c $"nsenter -t ($pid) -m -u -i -p -n -- nginx" out+err> /dev/null
    print "    nginx started"

    # Enable IP forwarding on the PVE node for iptables DNAT
    ^container exec $node bash -c "echo 1 > /proc/sys/net/ipv4/ip_forward" out+err> /dev/null

    print $"=== Ingress ready on ($node) \(VMID ($vmid), IP 172.16.99.2\) ==="
    print ""
}
