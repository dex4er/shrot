ssh root@localhost -p 2220 -i keys/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
