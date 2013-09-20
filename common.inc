#!/bin/sh

# short common functions
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

info() {
    echo "I: $*" 1>&2
}

die() {
    echo "E: $*" 1>&2
    run test -x /etc/init.d/rc.chroot >/dev/null 2>&1 && run /etc/init.d/rc.chroot stop >/dev/null 2>&1
    run test -x /etc/init.d/ssh >/dev/null 2>&1 && run /etc/init.d/ssh stop >/dev/null 2>&1
    umount_vfs >/dev/null 2>&1
    remove_tmpdir
    exit 1
}

error() {
    info "$@"
    info "Starting shell in chroot"
    run bash -i
    die "Cleaning up"
}

config() {
    k=$1
    shift

    if ! [ "$k" = "*" ]; then
        eval export $k=\'"$@"\'
    fi

    for p in $profiles; do
        if ! [ "$p" = "${p%=*}" ]; then
            if ! [ "$k" = "*" ]; then
                if [ "${p%=*}" = "$k" ]; then
                    v="${p#*=}"
                    eval export $k=\'`echo $v | sed 's/^[a-z_]*: //'`\'
                    return
                fi
            fi
        else
            if [ -f profiles/$p.yml ]; then
                p=profiles/$p.yml
            elif [ -f profiles/*/$p.yml ]; then
                p=`echo profiles/*/$p.yml`
            fi
            test -f "$p" || die "profile file $p not found"
            if ! [ "$k" = "*" ]; then
                if v=`grep "^$k: " "$p"`; then
                    eval export $k=\'`echo $v | sed 's/^[a-z_]*: //'`\'
                    return
                fi
            else
                for kk in `grep "^[a-z_]*: " "$p" | sed 's/:.*//'`; do
                    if v=`grep "^$kk: " "$p"`; then
                        eval export $kk=\'`echo $v | sed 's/^[a-z_]*: //'`\'
                    fi
                done
            fi
        fi
    done
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
    config '*'

    # get config variables
    config debootstrap $(command -v debootstrap >/dev/null && echo debootstrap || echo /usr/sbin/debootstrap)
    config arch $(dpkg --print-architecture 2>/dev/null || i386)
    config personality ''
    config variant ""
    config vendor Debian
    config suite stable

    config mirror $(mirror_url $vendor)

    config nameserver 8.8.8.8 8.8.4.4
    config hostname ''
    config dnsdomainname ''

    config instance 0
    config ssh_port $((2220 + $instance))
    config shrot_localhost 127.2.$((0 + $instance)).1

    config first_system_uid $((200 + 100 * $instance))
    config first_system_gid $((200 + 100 * $instance))


    config http_proxy $http_proxy
    config https_proxy $https_proxy

    config shrot_home ""
    config shrot_home /srv/shrot

    config base base

    config role standard
    config base_role base

    config shrot ""

    if [ -z "$shrot" ]; then
        shrot="$vendor-$suite-$arch-$(echo $role | sed 's/,/-/g')"
        shrot_base="$vendor-$suite-$arch-$base"

        if ! [ "$instance" = 0 ]; then
            shrot="$shrot-inst$instance"
            shrot_base="$shrot_base-inst$instance"
        fi

        if ! [ "$ssh_port" = $(( 2220 + $instance )) ]; then
            shrot="$shrot-ssh$ssh_port"
            shrot_base="$shrot_base-ssh$ssh_port"
        fi
    fi

    export archive="archives/shrot-$shrot.tgz"
    export archive_base="archives/shrot-$shrot_base.tgz"

    config host localhost
    config remote_port 0
    config remote_user root
    config ask_sudo_pass ''

    config playbook playbooks/$role/setup.yml

    config ansible_debug
    config ansible_playbook_arg ''

    export datetime="$(date +%Y-%m-%dT%H:%M:%S)"
    export datetime_filename="$(echo $datetime | sed -e 's/[:-]//g' -e 's/T/_/')"
}

mount_vfs() {
    run mount -t proc proc /proc
    run mount -t sysfs sysfs /sys
    run mount -t tmpfs tmpfs /dev/shm
    run mount -o gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts
}

umount_vfs() {
    if [ -n "$target" ] && [ -x "$target/bin/umount" ]; then
        run umount /dev/pts
        run umount /dev/shm
        run umount /sys
        run umount /proc
    fi
}

clean_tmp() {
    run sh -c 'find /tmp /var/tmp -mindepth 1 -print0 | xargs -0r rm -rf'
}

create_tmpdir() {
    target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'
}

remove_tmpdir() {
    if [ -n "$target" ] && ! [ "$target" = "/" ] && [ -d "$target" ]; then
        rm -rf "$target"
    fi
    rm -rf /tmp/ansible-ssh-localhost-$ssh_port-root
}
