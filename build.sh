#!/bin/sh

# Build Debian/Ubuntu image with working ssh and ansible commands
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

. $(dirname $0)/common.inc

./generate-keys.sh

gain_root "$@"

read_profile "$@"

info "Building shrot $shrot"

# temporary directory
target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

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

if [ "$instance" -gt 0 ]; then
    run sh -c 'dpkg-deb -x /var/cache/apt/archives/base-passwd_*.deb /'
    run cat /usr/share/base-passwd/passwd.master | awk -F: \
        'BEGIN { OFS=":" } { if ($3 > 0 && $3 < 10000) { $3 += 10000; $4 += 10000 };  print }' \
        | write /etc/passwd
    run cat /usr/share/base-passwd/group.master | awk -F: \
        'BEGIN { OFS=":" } { if ($3 > 0 && $3 < 10000) { $3 += 10000 };  print }' \
        | write /etc/group
    run sed -i s/FIRST_SYSTEM_UID=[0-9]*/FIRST_SYSTEM_UID=$(( $instance * 10000 + 100 ))/ /etc/adduser.conf
    run sed -i s/LAST_SYSTEM_UID=[0-9]*/LAST_SYSTEM_UID=$(( $instance * 10000 + 999 ))/ /etc/adduser.conf
    run sed -i s/FIRST_SYSTEM_GID=[0-9]*/FIRST_SYSTEM_GID=$(( $instance * 10000 + 100 ))/ /etc/adduser.conf
    run sed -i s/LAST_SYSTEM_GID=[0-9]*/LAST_SYSTEM_GID=$(( $instance * 10000 + 999 ))/ /etc/adduser.conf
    run sed -i s/FIRST_UID=[0-9]*/FIRST_UID=$(( $instance * 10000 + 1000 ))/ /etc/adduser.conf
    run sed -i s/LAST_UID=[0-9]*/FIRST_UID=$(( $instance * 10000 + 9999 ))/ /etc/adduser.conf
    run sed -i s/FIRST_GID=[0-9]*/FIRST_GID=$(( $instance * 10000 + 1000 ))/ /etc/adduser.conf
    run sed -i s/LAST_GID=[0-9]*/FIRST_GID=$(( $instance * 10000 + 9999 ))/ /etc/adduser.conf
    run sed -i s/USERS_GID=[0-9]*/USERS_GID=$(( $instance * 10000 + 100 ))/ /etc/adduser.conf
else
    run sed -i s/FIRST_SYSTEM_UID=[0-9]*/FIRST_SYSTEM_UID=$first_system_uid/ /etc/adduser.conf
    run sed -i s/FIRST_SYSTEM_GID=[0-9]*/FIRST_SYSTEM_GID=$first_system_gid/ /etc/adduser.conf
    run sed -i s/USERS_GID=[0-9]*/USERS_GID=$first_system_gid/ /etc/adduser.conf
fi

# additional tweaks
run mkdir -p /run/shm
echo 'none / chroot rw 0 0' | write /etc/mtab
echo $shrot | write /etc/debian_chroot

# debootstrap 2nd stage
run /debootstrap/debootstrap --second-stage

# mount vfs
mount_vfs

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
umount_vfs

# archive
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $archive
echo

# clean up
rm -rf $target
