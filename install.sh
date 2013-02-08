#!/bin/sh

die() {
    echo "E: $*" 1>&2
    exit 1
}


test `id -u` = 0 || exec sudo $0 "$@" || die 'sudo failed'

source=$1
target=${2:-/srv/shrot/$(basename $source)}

test -f $target && rm -rf $target

test -f $source || die "shrot archive file $source not found"

mkdir -p $target
cat $source | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

test -f /etc/default/schroot-sessions || install -m 644 files/etc_default_schroot-sessions /etc/default/schroot-sessions
test -f /etc/init.d/schroot-sessions || install -m 755 files/etc_init.d_schroot-sessions /etc/init.d/schroot-sessions
install -d /etc/schroot/setup.d/
test -f /etc/schroot/setup.d/12mtab || install -m 755 files/etc_schroot_setup.d_12mtab /etc/schroot/setup.d/12mtab
install -d /etc/schroot/shrot/
test -f /etc/schroot/shrot/copyfiles || install -m 755 files/etc_schroot_shrot_copyfiles /etc/schroot/shrot/copyfiles
test -f /etc/schroot/shrot/fstab || install -m 755 files/etc_schroot_shrot_fstab /etc/schroot/shrot/fstab
test -f /etc/schroot/shrot/nssdatabases || install -m 755 files/etc_schroot_shrot_nssdatabases /etc/schroot/shrot/nssdatabases
