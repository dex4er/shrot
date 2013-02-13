#!/bin/sh

. $(dirname $0)/common.inc

gain_root "$@"

read_profiles "$@"

create_tmpdir

test -f $archive || die "shrot archive $archive not found"

info "Entering shrot $shrot"

mkdir -p $target
cat $archive | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

run /etc/init.d/ssh start

./ansible-shrot.sh -m ping

run bash -i

run /etc/init.d/ssh stop

umount_vfs

remove_tmpdir
