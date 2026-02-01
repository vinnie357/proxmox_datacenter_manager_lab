#!/usr/bin/env nu

# Configure PVE nodes as remotes in PDM
# Creates API tokens on PVE nodes and registers them with PDM

def main [] {
    let root_password = ($env.ROOT_PASSWORD? | default "")

    if ($root_password | is-empty) {
        print "ERROR: ROOT_PASSWORD not set in .env"
        exit 1
    }

    # Check if PDM is running
    if not (is_running "pdm") {
        print "ERROR: PDM is not running. Start with: mise start"
        exit 1
    }

    print "Configuring PVE remotes in PDM..."
    print ""

    # Get PDM auth
    let pdm_auth = (get_pdm_auth $root_password)
    if ($pdm_auth | is-empty) {
        print "ERROR: Failed to authenticate with PDM"
        exit 1
    }

    # Configure each PVE node
    for node in ["pve-1" "pve-2" "pve-3"] {
        print $"Configuring ($node)..."
        configure_remote $node $root_password $pdm_auth
    }

    print ""
    print "Done. Check PDM UI for configured remotes."
}

def is_running [name: string] {
    let output = try {
        ^container list | lines | skip 1 | where { |line| ($line | str contains $name) and ($line | str contains "running") }
    } catch {
        []
    }
    ($output | length) > 0
}

def get_container_ip [name: string] {
    try {
        let line = (^container list | lines | skip 1 | where { |l| $l | str contains $name } | first)
        $line | split row -r '\s+' | get 5 | split row '/' | first
    } catch {
        ""
    }
}

def get_pdm_auth [password: string] {
    try {
        let response = (^curl -sk -i -X POST "https://localhost:8443/api2/json/access/ticket"
            -d $"username=root@pam&password=($password)" | lines)

        let cookie_line = ($response | where { |l| $l | str starts-with "set-cookie:" } | first)
        let cookie = ($cookie_line | str replace "set-cookie: " "" | split row ";" | first)

        let body_line = ($response | last)
        let csrf = ($body_line | parse -r '"CSRFPreventionToken":"([^"]+)"' | get capture0 | first)

        {cookie: $cookie, csrf: $csrf}
    } catch {
        {}
    }
}

def get_pve_auth [ip: string, password: string] {
    try {
        # PVE returns ticket in JSON body (no set-cookie header)
        let response = (^curl -sk -X POST $"https://($ip):8006/api2/json/access/ticket"
            -d $"username=root@pam&password=($password)")

        let data = ($response | from json | get data)
        let ticket = $data.ticket
        let csrf = $data.CSRFPreventionToken

        {cookie: $"PVEAuthCookie=($ticket)", csrf: $csrf, ticket: $ticket}
    } catch {
        {}
    }
}

def create_pve_token [ip: string, pve_auth: record, token_id: string] {
    try {
        # Delete existing token if any
        ^curl -sk -X DELETE $"https://($ip):8006/api2/json/access/users/root@pam/token/($token_id)" -H $"Cookie: ($pve_auth.cookie)" -H $"CSRFPreventionToken: ($pve_auth.csrf)" out+err> /dev/null

        # Create API token on PVE node
        let response = (^curl -sk -X POST $"https://($ip):8006/api2/json/access/users/root@pam/token/($token_id)"
            -H $"Cookie: ($pve_auth.cookie)"
            -H $"CSRFPreventionToken: ($pve_auth.csrf)"
            -d "privsep=0")

        let data = ($response | from json)
        if ($data.data? | is-not-empty) {
            $data.data.value
        } else {
            ""
        }
    } catch {
        ""
    }
}

def check_remote_exists [pdm_auth: record, remote_id: string] {
    try {
        # List all remotes and check if this one exists
        let response = (^curl -sk "https://localhost:8443/api2/json/remotes/remote"
            -H $"Cookie: ($pdm_auth.cookie)"
            -H $"CSRFPreventionToken: ($pdm_auth.csrf)")

        let data = ($response | from json)
        let remotes = ($data.data? | default [])
        $remotes | any { |r| ($r.id? | default "") == $remote_id }
    } catch {
        false
    }
}

def get_pve_fingerprint [ip: string] {
    try {
        # Get SHA256 fingerprint from PVE's self-signed certificate
        let output = (echo "" | ^openssl s_client -connect $"($ip):8006" err> /dev/null | ^openssl x509 -noout -fingerprint -sha256)
        # Extract just the fingerprint value
        $output | str replace "sha256 Fingerprint=" "" | str trim
    } catch {
        ""
    }
}

def add_pdm_remote [pdm_auth: record, remote_id: string, ip: string, token_id: string, token_secret: string, fingerprint: string] {
    try {
        let authid = $"root@pam!($token_id)"
        # Include fingerprint in the node address format: "ip:port,fingerprint=XYZ"
        let nodes = $"($ip):8006,fingerprint=($fingerprint)"

        let response = (^curl -sk -X POST "https://localhost:8443/api2/json/remotes/remote"
            -H $"Cookie: ($pdm_auth.cookie)"
            -H $"CSRFPreventionToken: ($pdm_auth.csrf)"
            -H "Content-Type: application/json"
            -d $'{"id":"($remote_id)","type":"pve","authid":"($authid)","token":"($token_secret)","nodes":["($nodes)"]}')

        $response
    } catch { |e|
        $"Error: ($e)"
    }
}

def configure_remote [node: string, password: string, pdm_auth: record] {
    # Check if node is running
    if not (is_running $node) {
        print $"  ($node) not running, skipped"
        return
    }

    # Get node IP
    let ip = (get_container_ip $node)
    if ($ip | is-empty) {
        print $"  ($node) could not get IP, skipped"
        return
    }
    print $"  IP: ($ip)"

    # Check if already configured
    if (check_remote_exists $pdm_auth $node) {
        print $"  ($node) already configured in PDM"
        return
    }

    # Authenticate with PVE node
    let pve_auth = (get_pve_auth $ip $password)
    if ($pve_auth | is-empty) {
        print $"  ($node) failed to authenticate with PVE"
        return
    }
    print $"  Authenticated with PVE"

    # Create API token
    let token_id = "pdm"
    let token_secret = (create_pve_token $ip $pve_auth $token_id)
    if ($token_secret | is-empty) {
        print $"  ($node) failed to create API token - may already exist"
        return
    }
    print $"  Created API token"

    # Get certificate fingerprint
    let fingerprint = (get_pve_fingerprint $ip)
    if ($fingerprint | is-empty) {
        print $"  ($node) could not get certificate fingerprint"
        return
    }
    print $"  Got fingerprint"

    # Add to PDM
    let result = (add_pdm_remote $pdm_auth $node $ip $token_id $token_secret $fingerprint)
    print $"  PDM response: ($result)"
}
