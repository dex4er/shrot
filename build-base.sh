#!/bin/sh

# Build Debian/Ubuntu image with working ssh and ansible commands
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

. $(dirname $0)/common.inc

./generate-keys.sh

gain_root "$@"

read_profiles "$@"

info "Building shrot $shrot"

create_tmpdir

# debootstrap 1st stage
$personality $debootstrap \
    --arch=$arch \
    --variant=${variant:--} \
    --include=openssh-server,python-apt,sudo,resolvconf \
    --foreign \
    $suite $target || die 'debootstrap failed'

# tweak uids and gids
run test -f /usr/share/adduser/adduser.conf || run sh -c 'dpkg-deb -x /var/cache/apt/archives/adduser_*.deb /'
run cp /usr/share/adduser/adduser.conf /etc/adduser.conf

run sed -i s/FIRST_SYSTEM_UID=[0-9]*/FIRST_SYSTEM_UID=$first_system_uid/ /etc/adduser.conf
run sed -i s/FIRST_SYSTEM_GID=[0-9]*/FIRST_SYSTEM_GID=$first_system_gid/ /etc/adduser.conf
run sed -i s/USERS_GID=[0-9]*/USERS_GID=$first_system_gid/ /etc/adduser.conf

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
printf "127.0.0.1\tlocalhost\n" | write /etc/hosts
for n in `echo $nameserver | sed 's/[^0-9.:]/ /g'`; do
    echo "nameserver $n"
done | write /etc/resolvconf/resolv.conf.d/base
run rm -f /etc/resolvconf/resolv.conf.d/original
run rm -f /run/resolvconf/interface/original.resolvconf

# reset hostname and set dnsdomainname
run rm -f /etc/hostname
if [ -n "$dnsdomainname" ]; then
    echo $dnsdomainname | write /etc/dnsdomainname
fi

# configure apt
echo "deb $mirror $suite main" | write /etc/apt/sources.list

# wrapper for initctl and upstart-job
run dpkg-divert --rename /sbin/initctl
cat files/sbin_initctl | write_x /sbin/initctl
run dpkg-divert --divert /lib/init/upstart-job.sh --rename /lib/init/upstart-job
cat files/lib_init_upstart-job | write_x /lib/init/upstart-job

# clean all init.d scripts for level 0 (setup-stop) and 2 (setup-start)
run sh -c 'rm -f /etc/rc[02].d/[SK]*'

# init.d rc.local
run update-rc.d -f rc.local remove >/dev/null
run update-rc.d rc.local start 99 2 3 4 5 . >/dev/null

# init.d dnsdomainname.sh
cat files/etc_init.d_dnsdomainname.sh | write_x /etc/init.d/dnsdomainname.sh
run sed -i 's/^\(# Default-Start:\).*$/\1     S 2/' /etc/init.d/dnsdomainname.sh
run update-rc.d dnsdomainname.sh start 02 S 2 . >/dev/null

# init.d sudo
run update-rc.d -f sudo remove >/dev/null
run update-rc.d sudo start 75 2 3 4 5 . >/dev/null

# init.d rsyslog
cat files/etc_init.d_rsyslog | write_x /etc/init.d/rsyslog.sysv
run update-rc.d -f rsyslog remove >/dev/null
run update-rc.d rsyslog start 10 2 3 4 5 . start 30 0 6 . stop 90 1 . >/dev/null

# init.d cron
cat files/etc_init.d_cron | write_x /etc/init.d/cron.sysv
run update-rc.d -f cron remove >/dev/null
run update-rc.d cron start 89 2 3 4 5 . >/dev/null

# init.d resolvconf
cat files/etc_init.d_resolvconf | write_x /etc/init.d/resolvconf.sysv
run sed -i 's/^\(# Default-Start:\).*$/\1     S 2/' /etc/init.d/resolvconf
run update-rc.d -f resolvconf remove >/dev/null
run update-rc.d resolvconf start 38 S 2 . stop 89 0 6 . >/dev/null

# init.d networking
run ln -s /bin/false /bin/init_is_upstart
cat files/etc_init.d_networking | write_x /etc/init.d/networking.sysv
run sed -i 's/^\(# Default-Start:\).*$/\1     S 2/' /etc/init.d/networking
run update-rc.d -f networking remove >/dev/null
run update-rc.d networking start 40 S 2 . start 35 0 6 . >/dev/null

# init.d ssh
run sed -i 's/^\(# Default-Stop:\).*$/\1\t\t0 6/' /etc/init.d/ssh
run update-rc.d -f ssh remove >/dev/null
run update-rc.d ssh start 16 2 3 4 5 . stop 90 0 6 . >/dev/null

# installing rc.chroot
cat files/etc_init.d_rc.chroot | write_x /etc/init.d/rc.chroot

# configure ssh server
run sed -i -e "s/^Port .*/Port $ssh_port/" /etc/ssh/sshd_config

# configure syslog
run sed -i 's/^\$ModLoad imklog/#&/' /etc/rsyslog.conf

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
remove_tmpdir
