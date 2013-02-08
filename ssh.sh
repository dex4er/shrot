ssh root@localhost -p 2222 -i keys/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
