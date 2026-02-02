#!/usr/bin/env nu

# Show lab status including container state and PDM remotes

def main [] {
    # Get container status
    print "Container Status"
    print "================"
    let containers = get_containers
    if ($containers | is-empty) {
        print "No containers running"
    } else {
        print ($containers | table)
    }

    # Try to get PDM status if running and password configured
    let pdm_running = ($containers | where name == "pdm" | where state == "running" | length) > 0
    let root_password = ($env.ROOT_PASSWORD? | default "")

    if $pdm_running and ($root_password | is-not-empty) {
        print ""
        print "PDM Remotes"
        print "==========="
        let remotes = get_pdm_remotes $root_password
        if ($remotes | is-empty) {
            print "No remotes configured or auth failed"
        } else {
            print ($remotes | table)
        }

        print ""
        print "PDM Resources"
        print "============="
        let resources = get_pdm_resources $root_password
        if ($resources | is-empty) {
            print "No resources found"
        } else {
            print ($resources | table)
        }
    } else if $pdm_running {
        print ""
        print "Set ROOT_PASSWORD in .env to see PDM status"
    }
}

def get_containers [] {
    try {
        let output = (^container list --format json | complete)
        if $output.exit_code != 0 {
            return []
        }
        let containers = ($output.stdout | from json)
        $containers | where status == "running" | each { |c|
            let cfg = $c.configuration
            let name = $cfg.id
            let image_name = ($cfg.image.reference | split row "/" | last | split row ":" | first)
            let mem_mb = ($cfg.resources.memoryInBytes / 1048576 | math round)
            let net = if ($c.networks | is-not-empty) { $c.networks | first } else { {} }
            let addr = ($net.ipv4Address? | default "-" | split row "/" | first)
            let hostname = ($net.hostname? | default "" | str trim --right --char ".")

            # Determine port based on container type
            let port = if $name == "pdm" {
                8443
            } else if ($name | str starts-with "pve") {
                8006
            } else if $name == "pbs" {
                8007
            } else {
                8006
            }

            let url = if ($hostname | is-not-empty) {
                $"https://($hostname):($port)"
            } else if $addr != "-" {
                $"https://($addr):($port)"
            } else {
                "-"
            }

            {
                name: $name
                url: $url
                state: $c.status
                addr: $addr
                cpus: $cfg.resources.cpus
                memory: $"($mem_mb)M"
                image: $image_name
            }
        }
    } catch {
        []
    }
}

def get_pdm_auth [password: string] {
    try {
        let response = (^curl -sk -i -X POST "https://localhost:8443/api2/json/access/ticket"
            -d $"username=root@pam&password=($password)" | lines)

        let cookie_line = ($response | where { |l| $l | str starts-with "set-cookie:" } | first)
        let cookie = ($cookie_line | str replace "set-cookie: " "" | split row ";" | first)

        let body_line = ($response | last)
        let csrf = ($body_line | from json | get data.CSRFPreventionToken)

        {cookie: $cookie, csrf: $csrf}
    } catch {
        {}
    }
}

def get_pdm_remotes [password: string] {
    let auth = (get_pdm_auth $password)
    if ($auth | is-empty) {
        return []
    }

    try {
        # Get remotes
        let remotes_resp = (^curl -sk "https://localhost:8443/api2/json/remotes/remote"
            -H $"Cookie: ($auth.cookie)"
            -H $"CSRFPreventionToken: ($auth.csrf)")
        let remotes = ($remotes_resp | from json | get data)

        # Get resources for status
        let resources_resp = (^curl -sk "https://localhost:8443/api2/json/resources/list"
            -H $"Cookie: ($auth.cookie)"
            -H $"CSRFPreventionToken: ($auth.csrf)")
        let resources = ($resources_resp | from json | get data)

        $remotes | each { |r|
            let remote_resources = ($resources | where { |res| $res.remote == $r.id } | first | default {})
            let error = ($remote_resources.error? | default "")

            {
                remote: $r.id
                type: $r.type
                status: (if ($error | is-empty) { "ok" } else { $error })
            }
        }
    } catch {
        []
    }
}

def get_pdm_resources [password: string] {
    let auth = (get_pdm_auth $password)
    if ($auth | is-empty) {
        return []
    }

    try {
        let resp = (^curl -sk "https://localhost:8443/api2/json/resources/list"
            -H $"Cookie: ($auth.cookie)"
            -H $"CSRFPreventionToken: ($auth.csrf)")
        let data = ($resp | from json | get data)

        $data | each { |r|
            let resources = ($r.resources? | default [])
            let nodes = ($resources | where { |res| $res.type == "pve-node" or $res.type == "pbs-node" })
            let vms = ($resources | where type == "qemu")
            let cts = ($resources | where type == "lxc")
            let storage = ($resources | where type == "pve-storage")
            let networks = ($resources | where type == "pve-network")

            {
                remote: $r.remote
                nodes: ($nodes | length)
                storage: ($storage | length)
                networks: ($networks | length)
                vms: ($vms | length)
                cts: ($cts | length)
            }
        }
    } catch {
        []
    }
}
