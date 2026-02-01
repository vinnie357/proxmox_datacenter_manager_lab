#!/usr/bin/env nu

# Start the Proxmox lab using Apple Container
# Note: Volume mounts are NOT used because they overwrite container defaults.
# Use `mise backup` to export data from running containers.

def main [] {
    let project_root = ($env.PROJECT_ROOT? | default (pwd))
    let pdm_image = ($env.PDM_IMAGE? | default "ghcr.io/longqt-sea/proxmox-datacenter-manager")
    let pve_image = ($env.PVE_IMAGE? | default "ghcr.io/longqt-sea/proxmox-ve")

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

    # Set passwords if ROOT_PASSWORD is configured
    let root_password = ($env.ROOT_PASSWORD? | default "")
    if ($root_password | is-not-empty) {
        print ""
        print "Setting root passwords..."
        set_password "pdm" $root_password
        set_password "pve-1" $root_password
        set_password "pve-2" $root_password
        set_password "pve-3" $root_password
    }

    print ""
    print "Waiting for services to initialize..."
    sleep 10sec

    # Show status
    nu $"($project_root)/scripts/urls.nu"
}

def set_password [name: string, password: string] {
    try {
        ^container exec $name bash -c $"echo 'root:($password)' | chpasswd" out+err> /dev/null
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
        ^container rm $name out+err> /dev/null
    } catch { }
}

def start_pdm [image: string, dns_domain: string] {
    if (is_running "pdm") {
        print "  pdm already running"
        return
    }

    remove_if_exists "pdm"

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name pdm
                --platform linux/amd64
                --rosetta
                --virtualization
                --dns-domain $dns_domain
                -p 8443:8443
                $image)
        } else {
            (^container run -d
                --name pdm
                --platform linux/amd64
                --rosetta
                --virtualization
                -p 8443:8443
                $image)
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

    try {
        if ($dns_domain | is-not-empty) {
            (^container run -d
                --name $name
                --platform linux/amd64
                --rosetta
                --virtualization
                --dns-domain $dns_domain
                -p $"($web_port):8006"
                -p $"($ssh_port):22"
                $image)
        } else {
            (^container run -d
                --name $name
                --platform linux/amd64
                --rosetta
                --virtualization
                -p $"($web_port):8006"
                -p $"($ssh_port):22"
                $image)
        }
        print $"  ($name) started"
    } catch { |e|
        print $"  ERROR: ($e)"
    }
}
