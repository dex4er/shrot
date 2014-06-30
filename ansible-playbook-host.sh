#!/bin/sh

. $(dirname $0)/common.inc

read_profiles "$@"

test -f "$playbook" || die "Playbook $playbook not found"

vars="$(echo $(export | sed -e 's/^declare -x //' -e 's/^export //' | egrep '^[a-z][a-z_]*='))"

grep -qs "^$host$" ansible/hosts || echo $host >> ansible/hosts

case "$ansible_debug" in
    [0-9]) ansible_debug=-`perl -e "print 'v' x $ansible_debug"`;;
esac

info "Running ansible playbook $playbook on host $host"

ANSIBLE_ASK_SUDO_PASS=${ask_sudo_pass:-} \
ANSIBLE_HOSTS=ansible/hosts \
ANSIBLE_HOST_KEY_CHECKING=False \
ANSIBLE_REMOTE_PORT=${remote_port:-None} \
ANSIBLE_REMOTE_TEMP=/tmp/ansible-root \
ANSIBLE_REMOTE_USER=${remote_user:-root} \
ANSIBLE_TRANSPORT=ssh \
ansible-playbook -l $host -e "$vars" "$playbook" $ansible_debug $ansible_playbook_args
