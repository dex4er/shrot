#!/bin/sh

. $(dirname $0)/common.inc

gain_root "$@"

role=base

read_profiles "$@"

info "Entering shrot $shrot"

target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

test -f $archive || die "shrot archive $archive not found"

# unpack archive
mkdir -p $target
cat $archive | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

run /etc/init.d/ssh start

./ansible-shrot.sh -m ping

run /etc/init.d/ssh stop

# reread profile without base

role=

read_profiles "$@"

echo $shrot | write /etc/debian_chroot

umount_vfs

# repack archive
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $archive
echo

# clean up
rm -rf $target
