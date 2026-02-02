#!/usr/bin/env nu

# Start the Proxmox lab using Apple Container
#
# PVE containers require:
# - Service masking for Rosetta 2 compatibility (same as PDM image)
# - 4GB RAM minimum for pveproxy to start without OOM
#
# Uses named volumes for persistent storage.
# Entrypoint wrappers fix ownership before starting services.

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))
    let pdm_image = ($env.PDM_IMAGE? | default "ghcr.io/longqt-sea/proxmox-datacenter-manager")
    let pve_image = ($env.PVE_IMAGE? | default "ghcr.io/longqt-sea/proxmox-ve")
    let pbs_image = ($env.PBS_IMAGE? | default "ayufan/proxmox-backup-server")

    # Ensure container system is running
    try {
        ^container system start
    } catch { }

    # Check for DNS domain
    let dns_domain = get_dns_domain

    print "Starting Proxmox Datacenter Manager Lab..."
    if ($dns_domain | is-not-empty) {
        print $"Using DNS domain: ($dns_domain)"
    }
    print ""

    # Start PDM
    print "Starting PDM..."
    start_pdm $pdm_image $dns_domain

    # Start PVE nodes
    print "Starting PVE-1..."
    start_pve "pve-1" $pve_image 8006 2222 $dns_domain

    print "Starting PVE-2..."
    start_pve "pve-2" $pve_image 8007 2223 $dns_domain

    print "Starting PVE-3..."
    start_pve "pve-3" $pve_image 8008 2224 $dns_domain

    # Start PBS
    print "Starting PBS..."
    start_pbs $pbs_image $dns_domain

    # Set passwords if ROOT_PASSWORD is configured
    let root_password = ($env.ROOT_PASSWORD? | default "")
    if ($root_password | is-not-empty) {
        print ""
        print "Setting root passwords..."
        set_password "pdm" $root_password
        set_password "pve-1" $root_password
        set_password "pve-2" $root_password
        set_password "pve-3" $root_password
        set_pbs_password "pbs" $root_password
    }

    # Initialize PVE nodes (FQDN fix + local cluster)
    print ""
    print "Initializing PVE nodes..."
    nu $"($project_root)/scripts/pve-init.nu"

    print ""
    print "Waiting for services to initialize..."
    sleep 30sec

    # Configure remotes
    print ""
    nu $"($project_root)/scripts/remotes.nu"

    # Show status
    print ""
    nu $"($project_root)/scripts/urls.nu"
}

def set_password [name: string, password: string] {
    try {
        ^container exec $name bash -c $"echo 'root:($password)' | chpasswd" out+err> /dev/null
        print $"  ($name) password set"
    } catch { }
}

def set_pbs_password [name: string, password: string] {
    try {
        # PBS uses admin@pbs user with SHA-512 password hash in shadow.json
        # File must be owned by backup:backup with proper permissions
        let hash = (^openssl passwd -5 $password | str trim)
        ^container exec $name bash -c $"echo '{
  \"admin\": \"($hash)\"
}' > /etc/proxmox-backup/shadow.json && chown backup:backup /etc/proxmox-backup/shadow.json && chmod 600 /etc/proxmox-backup/shadow.json" out+err> /dev/null
        print $"  ($name) password set"
    } catch { }
}

def get_dns_domain [] {
    try {
        let dns_list = (^container system dns ls | lines | skip 1 | first)
        $dns_list | str trim
    } catch {
        ""
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

def remove_if_exists [name: string] {
    try {
        ^container rm -f $name out+err> /dev/null
    } catch { }
}

def start_pdm [image: string, dns_domain: string] {
    if (is_running "pdm") {
        print "  pdm already running"
        return
    }

    # Force remove any stopped/failed container
    try { ^container rm -f pdm out+err> /dev/null } catch { }

    # Entrypoint fixes volume ownership before starting services
    let init_script = "chown -R www-data:www-data /var/lib/proxmox-datacenter-manager && exec /entrypoint.sh /sbin/init --log-target=console --log-level=info"

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name pdm
                --platform linux/amd64
                --rosetta
                --virtualization
                --dns-domain $dns_domain
                --mount "type=volume,source=pdm-data,target=/var/lib/proxmox-datacenter-manager"
                -p 8443:8443
                --entrypoint /bin/bash
                $image
                -c $init_script out+err> /dev/null)
        } else {
            (^container run -d
                --name pdm
                --platform linux/amd64
                --rosetta
                --virtualization
                --mount "type=volume,source=pdm-data,target=/var/lib/proxmox-datacenter-manager"
                -p 8443:8443
                --entrypoint /bin/bash
                $image
                -c $init_script out+err> /dev/null)
        }
        print "  pdm started"
    } catch { |e|
        print $"  ERROR: ($e)"
    }
}

def start_pve [name: string, image: string, web_port: int, ssh_port: int, dns_domain: string] {
    if (is_running $name) {
        print $"  ($name) already running"
        return
    }

    remove_if_exists $name

    let project_root = ($env.PROJECT_ROOT? | default (pwd))

    # PVE requires service masking for Rosetta 2 compatibility and more memory
    # Install rrdtool (missing from image) for node status graphs
    # Also fix volume ownership before starting systemd
    let init_script = "
chown -R root:root /var/lib/vz/dump /var/lib/vz/template/iso 2>/dev/null
mkdir -p /var/lib/rrdcached/db/pve-node-9.0
systemctl mask proc-sys-fs-binfmt_misc.automount sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount kmod.service systemd-modules-load.service systemd-udevd.service 2>/dev/null
exec /entrypoint.sh /sbin/init --log-target=console --log-level=info
"

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name $name
                --platform linux/amd64
                --rosetta
                --virtualization
                --memory 4g
                --dns-domain $dns_domain
                --mount $"type=bind,source=($project_root)/data/($name)/dump,target=/var/lib/vz/dump"
                --mount $"type=bind,source=($project_root)/data/($name)/iso,target=/var/lib/vz/template/iso"
                -p $"($web_port):8006"
                -p $"($ssh_port):22"
                --entrypoint /bin/bash
                $image
                -c $init_script out+err> /dev/null)
        } else {
            (^container run -d
                --name $name
                --platform linux/amd64
                --rosetta
                --virtualization
                --memory 4g
                --mount $"type=bind,source=($project_root)/data/($name)/dump,target=/var/lib/vz/dump"
                --mount $"type=bind,source=($project_root)/data/($name)/iso,target=/var/lib/vz/template/iso"
                -p $"($web_port):8006"
                -p $"($ssh_port):22"
                --entrypoint /bin/bash
                $image
                -c $init_script out+err> /dev/null)
        }
        print $"  ($name) started"
    } catch { |e|
        print $"  ERROR: ($e)"
    }
}

def start_pbs [image: string, dns_domain: string] {
    if (is_running "pbs") {
        print "  pbs already running"
        return
    }

    remove_if_exists "pbs"

    # PBS requires tmpfs at /run for its shmem
    # Fix volume ownership before starting services
    let init_script = "chown -R backup:backup /var/lib/proxmox-backup /backups 2>/dev/null; mount -t tmpfs tmpfs /run && /usr/bin/runsvdir /runit"

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name pbs
                --platform linux/amd64
                --rosetta
                --virtualization
                --memory 2g
                --dns-domain $dns_domain
                --mount "type=volume,source=pbs-lib,target=/var/lib/proxmox-backup"
                --mount "type=volume,source=pbs-backups,target=/backups"
                -p 8009:8007
                --entrypoint /bin/bash
                $image
                -c $init_script out+err> /dev/null)
        } else {
            (^container run -d
                --name pbs
                --platform linux/amd64
                --rosetta
                --virtualization
                --memory 2g
                --mount "type=volume,source=pbs-lib,target=/var/lib/proxmox-backup"
                --mount "type=volume,source=pbs-backups,target=/backups"
                -p 8009:8007
                --entrypoint /bin/bash
                $image
                -c $init_script out+err> /dev/null)
        }
        print "  pbs started"
    } catch { |e|
        print $"  ERROR: ($e)"
    }
}
