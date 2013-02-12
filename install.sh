#!/bin/sh

. $(dirname $0)/common.inc

read_profiles "$@"

test -f playbooks/$role.yml || die "playbook for role $role not found"

test -f $archive || die "shrot archive $archive not found"

info "Installing shrot $shrot into $host via ansible"

vars="$(eval echo $(set|egrep '^(vendor|suite|arch|role|shrot|shrot_home)='))"

./ansible-playbook-host.sh -l $host -K -e "$vars" install.yml
