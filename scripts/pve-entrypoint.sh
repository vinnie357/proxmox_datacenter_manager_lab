#!/bin/bash
# Custom entrypoint for PVE on Apple Container
# Handles Rosetta 2 compatibility and missing kernel features

# Mask services that fail under Rosetta 2 (same as PDM)
# These services require kernel features not available in emulation
systemctl mask \
    proc-sys-fs-binfmt_misc.automount \
    sys-kernel-config.mount \
    sys-kernel-debug.mount \
    sys-kernel-tracing.mount \
    kmod.service \
    systemd-modules-load.service \
    systemd-udevd.service \
    2>/dev/null || true

# Remount filesystems as read-write (may already be rw)
mount -o remount,rw /sys/fs/cgroup 2>/dev/null || true
mount -o remount,rw /proc/sys 2>/dev/null || true
mount -o remount,rw /sys 2>/dev/null || true

# Only mount drm tmpfs if the directory exists
if [ -d /sys/class/drm ]; then
    mount -t tmpfs -o ro,noexec,nosuid tmpfs /sys/class/drm 2>/dev/null || true
fi

# Set shm size (ignore errors)
mount -o remount,size=1G /dev/shm 2>/dev/null || true

# Create device nodes (ignore if they exist)
mkdir -p /dev/net /dev/mapper 2>/dev/null || true
mknod /dev/kvm            c 10 232 2>/dev/null || true
mknod /dev/fuse           c 10 229 2>/dev/null || true
mknod /dev/zfs            c 10 249 2>/dev/null || true
mknod /dev/net/tun        c 10 200 2>/dev/null || true
mknod /dev/loop-control   c 10 237 2>/dev/null || true
mknod /dev/mapper/control c 10 236 2>/dev/null || true

# Set permissions (ignore errors)
chown root:kvm  /dev/kvm 2>/dev/null || true
chown root:disk /dev/loop-control 2>/dev/null || true
chmod 666 /dev/kvm /dev/zfs 2>/dev/null || true
chmod 660 /dev/loop-control 2>/dev/null || true
chmod 600 /dev/mapper/control 2>/dev/null || true

# Set root password if provided
if [ -n "$PASSWORD" ] && [ ! -f /etc/.password-set ]; then
    echo "root:$PASSWORD" | chpasswd
    touch /etc/.password-set
fi

exec "$@"
