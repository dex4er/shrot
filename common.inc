#!/bin/sh

# short common functions
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

info() {
    echo "I: $*" 1>&2
}

die() {
    echo "E: $*" 1>&2
    exit 1
}

config() {
    k=$1
    shift

    for p in $profiles; do
        test -f "profiles/$p.yml" && p="profiles/$p.yml"
        test -f "profiles/$p" && p="profiles/$p"
        test -f "$p" || die "profile file $p not found"
        if v=`grep "^$k: " "$p"`; then
            eval echo `echo $v | sed 's/^[a-z_]*: //'`
            return
        fi
    done

    echo "$@"
}

mirror_url() {
    case "$1" in
        Debian)
            echo http://ftp.debian.org/debian/
            ;;
        Ubuntu)
            echo http://archive.ubuntu.com/ubuntu/
            ;;
        *)
            die "Unknown Vendor"
    esac
}

run() {
    DEBIAN_FRONTEND=noninteractive \
    HOME=/dev/shm \
    LANG=C \
    LC_ALL=C \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    $personality chroot $target "$@"
}

write() {
    run tee "$1" >/dev/null
}

write_x() {
    write "$1"
    run chmod +x "$1"
}

gain_root() {
    test `id -u` = 0 || exec sudo $0 "$@" || die 'sudo failed; root privileges are required'
}

read_profiles() {
    profiles="$*"
    test -f profiles/default.yml && profiles="$profiles default"
    config test >/dev/null

    # get config variables
    debootstrap=`config debootstrap $(command -v debootstrap >/dev/null && echo debootstrap || echo /usr/sbin/debootstrap)`
    arch=`config arch $(dpkg --print-architecture 2>/dev/null || i386)`
    personality=`config personality ""`
    variant=`config variant ""`
    vendor=`config vendor Debian`
    suite=`config suite stable`

    mirror=`config mirror $(mirror_url $vendor)`

    nameserver=`config nameserver 8.8.8.8 8.8.4.4`

    instance=`config instance 0`
    export ssh_port=`config ssh_port $((2220 + $instance))`

    first_system_uid=`config first_system_uid $((200 + 100 * $instance))`
    first_system_gid=`config first_system_gid $((200 + 100 * $instance))`

    role=${role:-`config role base`}

    export http_proxy=`config http_proxy $http_proxy`
    export https_proxy=`config https_proxy $https_proxy`

    shrot=$vendor-$suite-$arch-$role

    test "$instance" = 0 || shrot=$shrot-inst$instance
    test "$ssh_port" = $(( 2220 + $instance )) || shrot=$shrot-ssh$ssh_port

    archive=archives/shrot-$shrot.tgz
}

mount_vfs() {
    run mount -t proc proc /proc
    run mount -t sysfs sysfs /sys
    run mount -t tmpfs tmpfs /dev/shm
    run mount -o gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
}

umount_vfs() {
    run umount /dev/pts
    run umount /dev/shm
    run umount /sys
    run umount /proc
}
