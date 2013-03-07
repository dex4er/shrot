#!/bin/sh

# Build Debian/Ubuntu image with working ssh and ansible commands
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

. $(dirname $0)/common.inc

./generate-keys.sh

gain_root "$@"

read_profiles "$@"

nc localhost $ssh_port </dev/null >/dev/null && die "TCP port $ssh_port is already used"

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

install -m 0700 -d $target/root/.ssh
install -m 0600 -o root -g root keys/id_rsa.pub $target/root/.ssh/authorized_keys_ansible

run /etc/init.d/ssh start "-p$ssh_port -oAuthorizedKeysFile=%h/.ssh/authorized_keys_ansible"

./ansible-playbook-shrot.sh "$@" host=localhost playbook=playbooks/ping.yml || error "playbook for ping failed"

./ansible-playbook-shrot.sh "$@" host=localhost || error "playbook $playbook failed"

./ansible-playbook-shrot.sh "$@" host=localhost playbook=playbooks/clean.yml || error "playbook for clean failed"

test -x $target/etc/init.d/rc.chroot && run /etc/init.d/rc.chroot stop
run /etc/init.d/ssh stop

clean_tmp

# umount vfs
umount_vfs

# archive
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $archive
echo

# clean up
remove_tmpdir
