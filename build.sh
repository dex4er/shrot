#!/bin/sh

# Build Debian/Ubuntu image with working ssh and ansible commands
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

die() {
    echo "E: $*" 1>&2
    exit 1
}

if [ -n "$1" ]; then
    profile_yml="$1"
    test -f "$profile_yml" || profile_yml="profiles/$1"
    test -f "$profile_yml" || die "profile file $1 not found"
fi

default_yml="profiles/default.yml"


config() {
    k=$1
    shift

    if [ -n "$profile_yml" ] && [ -f "$profile_yml" ] && grep -qs "^$k: " "$profile_yml"; then
        eval echo `grep "^$k: " "$profile_yml" | sed 's/^[a-z_]*: //'`
    elif [ -f "$default_yml" ] && grep -qs "^$k: " "$default_yml"; then
        eval echo `grep "^$k: " "$default_yml" | sed 's/^[a-z_]*: //'`
    else
        echo "$@"
    fi
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

# generate ssh keys if missing
./generate-keys.sh

# gain root privileges
test `id -u` = 0 || exec sudo $0 "$@" || die 'sudo failed; root privileges are required'

# temporary directory
target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

# get config variables
debootstrap=`config debootstrap $(command -v debootstrap >/dev/null && echo debootstrap || echo /usr/sbin/debootstrap)`
arch=`config arch $(dpkg --print-architecture 2>/dev/null || i386)`
personality=`config personality ""`
variant=`config variant ""`
vendor=`config vendor Debian`
suite=`config suite stable`

mirror=`config mirror $(mirror_url $vendor)`

nameserver=`config nameserver 8.8.8.8 8.8.4.4`
ssh_port=`config ssh_port 2222`
first_system_uid=`config first_system_uid 200`
first_system_gid=`config first_system_gid 200`

shrot=$vendor-$suite-$arch

export http_proxy=`config http_proxy $http_proxy`
export https_proxy=`config https_proxy $https_proxy`

# debootstrap 1st stage
$personality $debootstrap \
    --arch=$arch \
    --variant=${variant:--} \
    --include=openssh-server,python-apt,sudo \
    --foreign \
    $suite $target || die 'debootstrap failed'

# tweak uids and gids
run test -f /usr/share/adduser/adduser.conf || run sh -c 'dpkg-deb -x /var/cache/apt/archives/adduser_*.deb /'
run cp /usr/share/adduser/adduser.conf /etc/adduser.conf
run sed -i -e s/FIRST_SYSTEM_UID=100/FIRST_SYSTEM_UID=$first_system_uid/ -e s/FIRST_SYSTEM_GID=100/FIRST_SYSTEM_GID=$first_system_gid/ /etc/adduser.conf

# additional tweaks
run mkdir -p /run/shm
echo 'none / chroot rw 0 0' | write /etc/mtab
echo $shrot | write /etc/debian_chroot

# debootstrap 2nd stage
run /debootstrap/debootstrap --second-stage

# mount vfs
run mount -t proc proc /proc
run mount -t sysfs sysfs /sys
run mount -t tmpfs tmpfs /dev/shm
run mount -o gid=5,mode=620,ptmxmode=000 -t devpts devpts /dev/pts

# enable networking
echo '# This file is empty' | write /etc/network/interfaces
echo '127.0.0.1 localhost' | write /etc/hosts
for n in `echo $nameserver | sed 's/[^0-9.:]/ /g'`; do
    echo "nameserver $n"
done | write /etc/resolv.conf
run rm -f /etc/resolvconf/resolv.conf.d/original

# configure apt
echo "deb $mirror $suite main" | write /etc/apt/sources.list

# wrapper for initctl
run dpkg-divert --rename /sbin/initctl
cat files/sbin_initctl | write /sbin/initctl
run chmod +x /sbin/initctl

# clean all init.d scripts for level 0 (setup-stop) and 2 (setup-start)
run sh -c 'rm -f /etc/rc[02].d/[SK]*'

# init.d rc.local
run update-rc.d -f rc.local remove >/dev/null
run update-rc.d rc.local start 99 2 3 4 5 . >/dev/null

# init.d sudo
run update-rc.d -f sudo remove >/dev/null
run update-rc.d sudo start 75 2 3 4 5 . >/dev/null

# init.d rsyslog
if [ -h $target/etc/init.d/rsyslog ]; then
    run rm -f /etc/init.d/rsyslog
    cat files/etc_init.d_rsyslog | write /etc/init.d/rsyslog
    run chmod +x /etc/init.d/rsyslog
fi
run update-rc.d -f rsyslog remove >/dev/null
run update-rc.d rsyslog start 10 2 3 4 5 . start 30 0 6 . stop 90 1 . >/dev/null

# init.d cron
if [ -h $target/etc/init.d/cron ]; then
    run rm -f /etc/init.d/cron
    cat files/etc_init.d_cron | write /etc/init.d/cron
    run chmod +x /etc/init.d/cron
fi
run update-rc.d -f cron remove >/dev/null
run update-rc.d cron start 89 2 3 4 5 . >/dev/null

# init.d networking
run sed -i 's/^# Default-Start:.*$/&      S 2/' /etc/init.d/networking
run update-rc.d -f networking remove >/dev/null
run update-rc.d networking start 40 S . start 35 0 6 . >/dev/null

# init.d ssh
run sed -i 's/^# Default-Stop:.*$/&      0 6/' /etc/init.d/ssh
run update-rc.d -f ssh remove >/dev/null
run update-rc.d ssh start 16 2 3 4 5 . stop 90 0 6 . >/dev/null

# installing rc.chroot
cat files/etc_init.d_rc.chroot | write /etc/init.d/rc.chroot
run chmod +x /etc/init.d/rc.chroot

# configure ssh server
run sed -i -e "s/^Port [0-9]*$/Port $ssh_port/" /etc/ssh/sshd_config

# ssh keys
for a in dsa ecdsa rsa; do
    install -m 0600 -o root -g root keys/ssh_host_${a}_key $target/etc/ssh
    install -m 0644 -o root -g root keys/ssh_host_${a}_key.pub $target/etc/ssh
done
install -m 0700 -d $target/root/.ssh
install -m 0600 -o root -g root keys/id_rsa.pub $target/root/.ssh/authorized_keys

# clean up
run apt-get update
run apt-get clean
run rm -rf /debootstrap

# umount vfs
run umount /dev/pts
run umount /dev/shm
run umount /sys
run umount /proc

# make archive
test "$first_system_uid" = 200 || shrot=$shrot-uid$first_system_uid
test "$first_system_gid" = 200 || shrot=$shrot-gid$first_system_gid
test "$ssh_port" = 2222 || shrot=$shrot-ssh$ssh_port

result=archives/shrot-$shrot.tgz
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $result
echo

# clean up
rm -rf $target
