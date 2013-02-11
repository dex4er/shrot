#!/bin/sh

. $(dirname $0)/common.inc

gain_root "$@"

read_profile "$@"

info "Entering shrot $shrot"

target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

test -f $archive || die "shrot archive $archive not found"

mkdir -p $target
cat $archive | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

run bash -i

umount_vfs

# clean up
rm -rf $target
