#!/bin/sh

ANSIBLE_ASK_SUDO_PASS=${ask_sudo_pass} \
ANSIBLE_HOSTS=files/etc_ansible_hosts \
ANSIBLE_REMOTE_PORT=${remote_port:-22} \
ANSIBLE_REMOTE_USER=${remote_user:-root} \
ANSIBLE_TRANSPORT=ssh \
ansible "$@"
