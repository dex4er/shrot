#!/bin/sh

. $(dirname $0)/common.inc

read_profiles "$@"

test -f "$playbook" || die "Playbook $playbook not found"

vars="$(echo $(export | sed -e 's/^declare -x //' -e 's/^export //' | egrep '^[a-z][a-z_]*='))"

grep -qs "^$host$" ansible/hosts || echo $host >> ansible/hosts

case "$ansible_debug" in
    [0-9]) ansible_debug=-$(perl -e "print 'v' x $ansible_debug");;
esac

info "Running ansible playbook $playbook on shrot $host"

ANSIBLE_HOSTS=ansible/hosts \
ANSIBLE_HOST_KEY_CHECKING=False \
ANSIBLE_PRIVATE_KEY_FILE=keys/id_rsa \
ANSIBLE_REMOTE_PORT=${ssh_port:-2220} \
ANSIBLE_REMOTE_TEMP=/tmp/ansible-root \
ANSIBLE_REMOTE_USER=root \
ANSIBLE_TRANSPORT=ssh \
ansible-playbook -l $host -e "$vars" "$playbook" $ansible_debug $ansible_playbook_args
