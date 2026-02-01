#!/usr/bin/env nu

# Set root passwords on running containers

def main [] {
    let root_password = ($env.ROOT_PASSWORD? | default "")

    if ($root_password | is-empty) {
        print "ERROR: ROOT_PASSWORD not set in .env"
        exit 1
    }

    print "Setting root passwords..."
    set_password "pdm" $root_password
    set_password "pve-1" $root_password
    set_password "pve-2" $root_password
    set_password "pve-3" $root_password
    print "Done."
}

def set_password [name: string, password: string] {
    let running = try {
        let output = (^container list | lines | skip 1 | where { |line| ($line | str contains $name) and ($line | str contains "running") })
        $output | length
    } catch {
        0
    }

    if $running == 0 {
        print $"  ($name) not running, skipped"
        return
    }

    try {
        ^container exec $name bash -c $"echo 'root:($password)' | chpasswd" out+err> /dev/null
        print $"  ($name) password set"
    } catch {
        print $"  ($name) failed"
    }
}
