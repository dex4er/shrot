#!/bin/sh

. $(dirname $0)/common.inc

read_profiles "$@"

ssh -l root -p $ssh_port -i keys/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${host:-localhost}
