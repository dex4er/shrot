#!/bin/sh

. $(dirname $0)/common.inc

read_profiles "$@"

test -f $archive || die "shrot archive $archive not found"

info "Installing shrot $shrot into $host via ansible"

./ansible-playbook-host.sh "$@" playbook=playbooks/shrot/install.yml
