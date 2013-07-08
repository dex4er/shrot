shrot
=====

shrot or scrap-heap (Polish: szrot, German: schrott) is a place where can be
found recyclable and other material left over from product consumption, such
as part of vehicles, building supplies, and surplus materials. Unlike waste,
scrap has significant monetary value.

shrot is a tool for making recyclable chroot environment which can be run with
schroot command.

The shrot recyclable environment is a basic Debian distribution with own ssh
server. The environment works with ansible - the orchestration tool.

shrot is a sandboxing or "virtualizing" without virtualizing. It does not
require any special technologies on host, but schroot binary.


Requirements
============

Build system
------------

This is system where short archive is made.

 * debootstrap
 * sudo
 * ansible >= 1.2

Host system
-----------

This is system where shrot archive is unpacked and running.

 * ssh server
 * sudo
 * schroot >= 1.6
 * python2 >= 2.6
 * python-simplejson
 * python-yaml


Usage
=====

SSH keys
--------

    ./generate-keys.sh

Build base archive
------------------

    ./build-base.sh Debian wheezy i386

Build role archive
------------------

    ./build-role.sh Debian wheezy i386 role=phpmyadmin

Install role archive
--------------------

    ./install.sh Debian wheezy i386 role=phpmyadmin host=myhost remote_user=myuser ask_sudo_pass=yes shrot_home=/home/shrot

Parameters can be placed in profile configuration:

File profile/myhost.yml

    ---
    host: myhost
    remote_user: myuser
    ask_sudo_pass: yes
    shrot_home: /home/shrot

    ./install.sh Ubuntu precise i386 role=phpmyadmin myhost
