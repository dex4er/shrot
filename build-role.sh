#!/bin/sh

error() {
    info "$@"
    info "Starting shell in chroot"
    run bash -i
    die "Cleaning up"
}

. $(dirname $0)/common.inc

gain_root "$@"

read_profiles "$@"

if [ "$role" = "base" ]; then
    role=repacked
    read_profiles "$@"
fi

playbook=playbooks/$role/setup.yml

test -f $playbook || die "playbook for role $role not found"

create_tmpdir

test -f $archive_base || die "shrot archive $archive_base not found"

info "Entering shrot $shrot_base"

# unpack archive
mkdir -p $target
cat $archive_base | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

echo $shrot | write /etc/debian_chroot

run /etc/init.d/ssh start

./ansible-playbook-shrot.sh playbooks/ping.yml || error "playbook for ping failed"

./ansible-playbook-shrot.sh $playbook || error "playbook $playbook failed"

./ansible-playbook-shrot.sh playbooks/clean.yml || error "playbook for clean failed"

run /etc/init.d/rc.chroot stop

umount_vfs

# repack archive
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $archive
echo

remove_tmpdir
