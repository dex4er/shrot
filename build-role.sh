#!/bin/sh

. $(dirname $0)/common.inc

# check prerequisities
ansible --version >/dev/null 2>&1 || die "`printf 'ansible is not installed. You can install it by typing:\nsudo add-apt-repository ppa:rquillo/ansible\nsudo apt-get install ansible\n'`"

gain_root "$@"

read_profiles "$@"

roles=`echo $role | sed 's/,/\n/g' | uniq`

for r in $roles; do

    test $r = "base" && die "Use build-base.sh for base role"
    test -f playbooks/$r/setup.yml || die "Playbook for $r role not found"

done

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

./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/ping.yml "$@" || error "Playbook for ping failed"

./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/create_ssh_host_keys.yml "$@" || error "Playbook for creating new ssh host keys failed"

for r in $roles; do

    if [ -f playbooks/$r/prepare.yml ]; then
        ./ansible-playbook-shrot.sh host=localhost playbook=playbooks/$r/prepare.yml "$@" || error "Playbook for $r prepare failed"
    fi

done

for r in $roles; do

    ./ansible-playbook-shrot.sh host=localhost playbook=playbooks/$r/setup.yml "$@" || error "Playbook for $r setup failed"

done

./ansible-playbook-shrot.sh host=localhost playbook=playbooks/base/cleanup.yml "$@" || error "Playbook for cleanup failed"

run /etc/init.d/rc.chroot stop

clean_tmp

umount_vfs

# repack archive
run tar --create --directory / --numeric-owner --checkpoint=100 --checkpoint-action=ttyout=. --gzip . > $archive
echo

info "Created $archive shrot archive"

remove_tmpdir
