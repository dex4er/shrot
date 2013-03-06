#! /bin/sh
### BEGIN INIT INFO
# Provides:          dnsdomainname
# Required-Start:
# Required-Stop:
# Should-Start:      glibc
# Default-Start:     S 2
# Default-Stop:
# Short-Description: Set full hostname based on short hostname
# Description:       Updates /etc/hosts file based on /etc/hosts
#                    and /etc/domainname files
### END INIT INFO

PATH=/sbin:/bin

. /lib/init/vars.sh
. /lib/lsb/init-functions

do_start () {
	[ -f /etc/hostname ] && HOSTNAME="$(cat /etc/hostname)"

	[ -z "$HOSTNAME" ] && HOSTNAME="$(hostname)"

	# And set it to 'localhost' if no setting was found
	[ -z "$HOSTNAME" ] && HOSTNAME=localhost

	KERNEL_HOSTNAME="$(hostname)"

	# And set it to 'localhost' if no setting was found
	[ -z "$KERNEL_HOSTNAME" ] && KERNEL_HOSTNAME=localhost

	[ -f /etc/dnsdomainname ] && DNSDOMAINNAME="$(cat /etc/dnsdomainname)"

	# Keep current name if /etc/dnsdomainname is missing.
	[ -z "$DNSDOMAINNAME" ] && DNSDOMAINNAME="$(dnsdomainname 2>/dev/null)"

	[ "$VERBOSE" != no ] && log_action_begin_msg "Setting dnsdomainname to '$DNSDOMAINNAME'"

	localhost_regexp='^127\.0\.0\.1[[:space:]]';
	if grep -qs $localhost_regexp /etc/hosts; then
		sed -i -e '/^127\.0\.1\.1[[:space:]]/d' \
		       -e "/$localhost_regexp/a127.0.1.1\t${DNSDOMAINNAME:+$HOSTNAME.$DNSDOMAINNAME }$HOSTNAME" \
			/etc/hosts
	else
		sed -i -e '/^127\.0\.1\.1[[:space:]]/d' \
		       -e "1i127.0.1.1\t${DNSDOMAINNAME:+$HOSTNAME.$DNSDOMAINNAME }$HOSTNAME" \
			/etc/hosts
	fi
	ES=$?
	[ "$VERBOSE" != no ] && log_action_end_msg $ES
	exit $ES
}

do_status () {
	DNSDOMAINNAME=$(dnsdomainname)
	if [ "$DNSDOMAINNAME" ] ; then
		return 0
	else
		return 4
	fi
}

case "$1" in
  start|"")
	do_start
	;;
  restart|reload|force-reload)
	echo "Error: argument '$1' not supported" >&2
	exit 3
	;;
  stop)
	# No-op
	;;
  status)
	do_status
	exit $?
	;;
  *)
	echo "Usage: dnsdomainname.sh [start|stop]" >&2
	exit 3
	;;
esac

:
