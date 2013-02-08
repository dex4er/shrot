#!/bin/sh

die() {
    echo "E: $*" 1>&2
    exit 1
}

config_yml="$1"
test -f "profiles/$config_yml" && config_yml="profiles/$config_yml"

default_yml="profiles/default.yml"

config() {
    k=$1
    shift

    if [ -n "$config_yml" ] && [ -f "$config_yml" ] && grep -qs "^$k: " "$config_yml"; then
        eval echo `grep "^$k: " "$config_yml" | sed 's/^[a-z_]*: //'`
    elif [ -f "$default_yml" ] && grep -qs "^$k: " "$default_yml"; then
        eval echo `grep "^$k: " "$default_yml" | sed 's/^[a-z_]*: //'`
    else
        echo "$@"
    fi
}

run() {
    DEBIAN_FRONTEND=noninteractive \
    HOME=/dev/shm \
    LANG=C \
    LC_ALL=C \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    $personality chroot $target "$@"
}


test `id -u` = 0 || exec sudo $0 "$@" || die 'sudo failed'

# get config variables
debootstrap=`config debootstrap $(command -v debootstrap >/dev/null && echo debootstrap || echo /usr/sbin/debootstrap)`
arch=`config arch $(dpkg --print-architecture 2>/dev/null || i386)`
personality=`config personality ""`
variant=`config variant ""`
vendor=`config vendor Debian`
suite=`config suite stable`

ssh_port=`config ssh_port 2222`
first_system_uid=`config first_system_uid 200`
first_system_gid=`config first_system_gid 200`

shrot=$vendor-$suite-$arch-${variant:-base}
test "$first_system_uid" = 200 || shrot=$shrot-uid$first_system_uid
test "$first_system_gid" = 200 || shrot=$shrot-gid$first_system_gid
test "$ssh_port" = 2222 || shrot=$shrot-ssh$ssh_port

source=archives/shrot-$shrot.tgz
target=`mktemp -d -t shrot-XXXXXX` || die 'mktemp failed'

test -f $source || die "shrot archive not found"

mkdir -p $target
cat $source | ( cd $target || die "chdir failed"; tar zx --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. )
echo

mounts="/proc /sys /dev/shm /dev/pts"
for d in $mounts; do
    mount --bind $d $target/$d
done

run bash -i

# umount vfs
for d in $(echo $mounts | tac -s ' '); do
    umount $target/$d
done

# clean up
rm -rf $target
