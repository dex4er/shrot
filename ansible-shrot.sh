#!/bin/sh

test -f ansible/hosts || echo localhost > ansible/hosts

ANSIBLE_HOSTS=ansible/hosts \
ANSIBLE_REMOTE_PORT=${ssh_port:-2220} \
ANSIBLE_PRIVATE_KEY_FILE=keys/id_rsa \
ANSIBLE_REMOTE_TEMP=/tmp/ansible-root \
ANSIBLE_REMOTE_USER=root \
ANSIBLE_TRANSPORT=paramiko \
ansible "$@"
