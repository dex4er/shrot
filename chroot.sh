#!/bin/sh

. $(dirname $0)/common.inc

gain_root "$@"

read_profiles "$@"

create_tmpdir

if [ -f $archive ]; then
    archive_chroot=$archive
    shrot_chroot=$shrot
elif [ -f $archive_base ]; then
    archive_chroot=$archive_base
    shrot_chroot=$shrot_base
else
    die "neither shrot archive $archive nor $archive_base not found"
fi

info "Entering shrot $shrot_chroot"

mkdir -p $target
cat $archive_chroot | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mount_vfs

run /etc/init.d/rc.chroot start

./ansible-shrot.sh localhost -m ping

run env HOME=/root bash -i

run /etc/init.d/rc.chroot stop

umount_vfs

remove_tmpdir
