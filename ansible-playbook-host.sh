#!/bin/sh

. $(dirname $0)/common.inc

read_profiles "$@"

test -f "$playbook" || die "playbook $playbook not found"

vars="$(eval echo $(set|egrep '^(vendor|suite|arch|role|shrot|shrot_home|ssh_port)='))"

test -f ansible/hosts || echo localhost > ansible/hosts

ANSIBLE_ASK_SUDO_PASS=${ask_sudo_pass:-} \
ANSIBLE_HOSTS=ansible/hosts \
ANSIBLE_REMOTE_PORT=${remote_port:-22} \
ANSIBLE_REMOTE_TEMP=/tmp/ansible-root \
ANSIBLE_REMOTE_USER=${remote_user:-root} \
ANSIBLE_TRANSPORT=ssh \
ansible-playbook -l $host -e "$vars" "$playbook"
