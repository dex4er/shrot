shrot
=====

shrot or scrap-heap (Polish: szrot, German: schrott) is a place where can be
found recyclable and other material left over from product consumption, such
as part of vehicles, building supplies, and surplus materials. Unlike waste,
scrap has significant monetary value.

shrot is a tool for making recyclable chroot environment which can be run with
schroot command.

The shrot recyclable environment is a basic Debian/Ubuntu distribution with
own ssh server. The environment works with ansible - the orchestration tool.


Requirements
============

Build system
------------

This is system where short archive is made.

 * debootstrap
 * sudo
 * ansible

Host system
-----------

This is system where shrot archive is unpacked and running.

 * ssh server
 * sudo
 * schroot >= 1.6
 * python2 >= 2.6
 * pyyaml


Usage
=====

SSH keys
--------

    ./generate-keys.sh

Build base archive
------------------

    ./build-base.sh Ubuntu precise i386

Build role archive
------------------

    ./build-role.sh Ubuntu precise i386 phpmyadmin

Install role archive
--------------------

    ./install.sh host phpmyadmin
