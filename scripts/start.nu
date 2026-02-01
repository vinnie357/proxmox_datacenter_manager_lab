#!/usr/bin/env nu

# Start the Proxmox lab using Apple Container
#
# PVE containers require:
# - Service masking for Rosetta 2 compatibility (same as PDM image)
# - 4GB RAM minimum for pveproxy to start without OOM
#
# Volume mounts persist data across container restarts.
# Use `mise clean:data` to reset all persistent data.

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
    start_pdm $pdm_image $dns_domain $project_root

    # Start PVE nodes
    print "Starting PVE-1..."
    start_pve "pve-1" $pve_image 8006 2222 $dns_domain $project_root

    print "Starting PVE-2..."
    start_pve "pve-2" $pve_image 8007 2223 $dns_domain $project_root

    print "Starting PVE-3..."
    start_pve "pve-3" $pve_image 8008 2224 $dns_domain $project_root

    # Start PBS
    print "Starting PBS..."
    start_pbs $pbs_image $dns_domain $project_root

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
        $list | any { |c| $c.ID == $name }
    } catch {
        false
    }
}

def remove_if_exists [name: string] {
    try {
        ^container rm -f $name out+err> /dev/null
    } catch { }
}

def start_pdm [image: string, dns_domain: string, project_root: string] {
    if (is_running "pdm") {
        print "  pdm already running"
        return
    }

    # Force remove any stopped/failed container
    try { ^container rm -f pdm out+err> /dev/null } catch { }

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name pdm
                --platform linux/amd64
                --rosetta
                --virtualization
                --dns-domain $dns_domain
                -v $"($project_root)/data/pdm-config:/etc/proxmox-datacenter-manager"
                -v $"($project_root)/data/pdm-data:/var/lib/proxmox-datacenter-manager"
                -p 8443:8443
                $image out+err> /dev/null)
        } else {
            (^container run -d
                --name pdm
                --platform linux/amd64
                --rosetta
                --virtualization
                -v $"($project_root)/data/pdm-config:/etc/proxmox-datacenter-manager"
                -v $"($project_root)/data/pdm-data:/var/lib/proxmox-datacenter-manager"
                -p 8443:8443
                $image out+err> /dev/null)
        }
        print "  pdm started"
    } catch { |e|
        print $"  ERROR: ($e)"
    }
}

def start_pve [name: string, image: string, web_port: int, ssh_port: int, dns_domain: string, project_root: string] {
    if (is_running $name) {
        print $"  ($name) already running"
        return
    }

    remove_if_exists $name

    # PVE requires service masking for Rosetta 2 compatibility and more memory
    # Services that fail under Rosetta are masked before starting systemd
    let init_script = "
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
                -v $"($project_root)/data/($name)/dump:/var/lib/vz/dump"
                -v $"($project_root)/data/iso:/var/lib/vz/template/iso"
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
                -v $"($project_root)/data/($name)/dump:/var/lib/vz/dump"
                -v $"($project_root)/data/iso:/var/lib/vz/template/iso"
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

def start_pbs [image: string, dns_domain: string, project_root: string] {
    if (is_running "pbs") {
        print "  pbs already running"
        return
    }

    remove_if_exists "pbs"

    # PBS requires tmpfs at /run for its shmem
    let init_script = "mount -t tmpfs tmpfs /run && /usr/bin/runsvdir /runit"

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name pbs
                --platform linux/amd64
                --rosetta
                --virtualization
                --memory 2g
                --dns-domain $dns_domain
                -v $"($project_root)/data/pbs-config:/etc/proxmox-backup"
                -v $"($project_root)/data/pbs-lib:/var/lib/proxmox-backup"
                -v $"($project_root)/data/pbs-logs:/var/log/proxmox-backup"
                -v $"($project_root)/data/pbs-backups:/backups"
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
                -v $"($project_root)/data/pbs-config:/etc/proxmox-backup"
                -v $"($project_root)/data/pbs-lib:/var/lib/proxmox-backup"
                -v $"($project_root)/data/pbs-logs:/var/log/proxmox-backup"
                -v $"($project_root)/data/pbs-backups:/backups"
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
