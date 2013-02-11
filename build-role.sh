#!/bin/sh

. $(dirname $0)/common.inc

gain_root "$@"

read_profile profile/base.yml "$@"

info "Entering shrot $shrot"

target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

test -f $archive || die "shrot archive $archive not found"

# unpack archive
mkdir -p $target
cat $archive | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

run /etc/init.d/ssh start

./ansible-inst0.sh -m ping

run /etc/init.d/ssh stop

umount_vfs

# reread profile without base.yml
read_profile "$@"

# repack archive
run sh -c 'cd /; tar c . --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=.' | gzip -9 > $archive
echo

# clean up
rm -rf $target
