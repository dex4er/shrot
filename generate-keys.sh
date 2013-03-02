#!/bin/sh

# Generate ssh keys used for shrot
#
# (c) 2013 Piotr Roszatycki <piotr.roszatycki@gmail.com>

create_key() {
    msg="$1"
    shift
    comment="$1"
    shift
    file="$1"
    shift

    if [ ! -f "$file" ]; then
        echo -n $msg
        ssh-keygen -q -f "$file" -N '' -C "$comment" "$@"
        ssh-keygen -v -f "$file" -l > "$file.asc"
        echo
    fi
}

mkdir -p keys

# Client keys
create_key "Creating SSH2 RSA client key; this may take some time ..." \
    ansible@shrot \
    keys/id_rsa -t rsa

# Server keys
create_key "Creating SSH2 RSA server key; this may take some time ..." \
    root@shrot \
    keys/ssh_host_rsa_key -t rsa
create_key "Creating SSH2 DSA server key; this may take some time ..." \
    root@shrot \
    keys/ssh_host_dsa_key -t dsa
create_key "Creating SSH2 ECDSA server key; this may take some time ..." \
    root@shrot \
    keys/ssh_host_ecdsa_key -t ecdsa

