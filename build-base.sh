#!/bin/sh

# Build Debian/Ubuntu image with working ssh and ansible commands
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

. $(dirname $0)/common.inc

# check prerequisities
ansible --version >/dev/null 2>&1 || die "`printf 'ansible is not installed. You can install it by typing:\nsudo add-apt-repository ppa:rquillo/ansible\nsudo apt-get install ansible\n'`"
debootstrap --version >/dev/null 2>&1 || die "`printf 'debootstrap is not installed. You can install it by typing:\nsudo apt-get install debootstrap\n'`"
nc -h >/dev/null 2>&1 || die "`printf 'nc is not installed. You can install it by typing:\nsudo apt-get install netcat\n'`"

# make these files before we gain root
./generate-keys.sh
grep -qs "^localhost$" ansible/hosts || echo localhost >> ansible/hosts

gain_root "$@"

read_profiles "$@"

nc localhost $ssh_port </dev/null >/dev/null && die "TCP port $ssh_port is already used"

roles=`echo $role | sed 's/,/\n/g' | uniq`

info "Building shrot $shrot"

create_tmpdir

# debootstrap 1st stage
$personality $debootstrap \
    --arch=$arch \
    --variant=${variant:--} \
    --include=openssh-server,python-apt \
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

# add ansible ssh keys
install -m 0700 -d $target/root/.ssh
install -m 0600 -o root -g root keys/id_rsa.pub $target/root/.ssh/authorized_keys_ansible

# start ssh server
run /etc/init.d/ssh start "-p$ssh_port -oAuthorizedKeysFile=%h/.ssh/authorized_keys_ansible"

# run the next stage with ansible playbook
./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/ping.yml "$@" || error "Playbook for ping failed"

for r in $roles; do

    if [ -f playbooks/$r/prepare.yml ]; then
        ./ansible-playbook-shrot.sh host=localhost playbook=playbooks/$r/prepare.yml "$@" || error "Playbook for $r prepare failed"
    fi

done

for r in $roles; do

    ./ansible-playbook-shrot.sh host=localhost playbook=playbooks/$r/setup.yml "$@" || error "Playbook for $r setup failed"

done

./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/cleanup.yml "$@" || error "Playbook for cleanup failed"

test -x $target/etc/init.d/rc.chroot && run /etc/init.d/rc.chroot stop
run /etc/init.d/ssh stop

clean_tmp

# umount vfs
umount_vfs

# archive
run tar --create --directory / --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. --gzip . > $archive_base
echo

info "Created $archive_base shrot archive"

# clean up
remove_tmpdir
