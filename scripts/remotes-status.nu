#!/usr/bin/env nu

# Show PDM remotes and their status

def main [] {
    let root_password = ($env.ROOT_PASSWORD? | default "")

    if ($root_password | is-empty) {
        print "ERROR: ROOT_PASSWORD not set in .env"
        exit 1
    }

    # Get PDM auth
    let pdm_auth = (get_pdm_auth $root_password)
    if ($pdm_auth | is-empty) {
        print "ERROR: Failed to authenticate with PDM"
        exit 1
    }

    # Get remotes
    let remotes_resp = (^curl -sk "https://localhost:8443/api2/json/remotes/remote"
        -H $"Cookie: ($pdm_auth.cookie)"
        -H $"CSRFPreventionToken: ($pdm_auth.csrf)")
    let remotes = ($remotes_resp | from json | get data)

    # Get resources/status for each remote
    let resources_resp = (^curl -sk "https://localhost:8443/api2/json/resources/list"
        -H $"Cookie: ($pdm_auth.cookie)"
        -H $"CSRFPreventionToken: ($pdm_auth.csrf)")
    let resources = ($resources_resp | from json | get data)

    # Build status table
    let status = ($remotes | each { |r|
        let remote_resources = ($resources | where { |res| $res.remote == $r.id } | first | default {})
        let error = ($remote_resources.error? | default "")
        let res_count = if ($remote_resources.resources? | is-not-empty) {
            $remote_resources.resources | length
        } else {
            0
        }

        # Extract just the host:port from nodes (strip fingerprint)
        let node_addrs = ($r.nodes | each { |n| $n | split row "," | first })

        {
            id: $r.id
            type: $r.type
            node: ($node_addrs | str join ", ")
            status: (if ($error | is-empty) { "✓ ok" } else { $"✗ ($error)" })
            resources: $res_count
        }
    })

    $status
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
