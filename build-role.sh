#!/bin/sh

. $(dirname $0)/common.inc

# check prerequisities
ansible --version >/dev/null 2>&1 || die "`printf 'ansible is not installed. You can install it by typing:\nsudo add-apt-repository ppa:rquillo/ansible\nsudo apt-get install ansible\n'`"

gain_root "$@"

read_profiles "$@"

if [ "$role" = "base" ]; then
    role=repacked
    read_profiles "$@"
fi

test -f $playbook || die "playbook for role $role not found"

create_tmpdir

test -f $archive_base || die "shrot archive $archive_base not found"

info "Entering shrot $shrot_base"

# unpack archive
mkdir -p $target
tar --extract --directory $target --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. --gzip --file $archive_base
echo

mount_vfs

echo $shrot | write /etc/debian_chroot

run /etc/init.d/ssh start

./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/ping.yml "$@" || error "playbook for ping failed"

./ansible-playbook-shrot.sh host=localhost "$@" || error "playbook $playbook failed"

./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/cleanup.yml "$@" || error "playbook for cleanup failed"

run /etc/init.d/rc.chroot stop

clean_tmp

umount_vfs

# repack archive
run tar --create --directory / --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. --gzip . > $archive
echo

info "Created $archive shrot archive"

remove_tmpdir
