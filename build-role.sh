#!/bin/sh

. $(dirname $0)/common.inc

gain_root "$@"

read_profiles "$@"

test -f playbooks/$role.yml || die "playbook for role $role not found"

target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

test -f $archive_base || die "shrot archive $archive_base not found"

info "Entering shrot $shrot_base"

# unpack archive
mkdir -p $target
cat $archive_base | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

echo $shrot | write /etc/debian_chroot

run /etc/init.d/ssh start

./ansible-playbook-shrot.sh playbooks/$role.yml

run /etc/init.d/rc.chroot stop

umount_vfs

# repack archive
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $archive
echo

# clean up
rm -rf $target
