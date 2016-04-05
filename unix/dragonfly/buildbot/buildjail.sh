#! /bin/sh

IPADDR="10.0.0.220"

verbose=1
logfile=$(mktemp)

#
# info message
# Display an informational message, typically under
#verbose mode.
info()
{
    local msg=$1
    shift

    [ ${verbose} -gt 0 ] && echo "INFO: " ${msg} $*
}

#
# err exitval message
#     Display an error and exit.
#
err()
{
    exitval=${1:-1}
    shift

    echo 1>&2 "ERROR: $*"
    exit $exitval
}

#
# runcmd cmd
# Execute a command
runcmd()
{
    local logf=${logfile}
    local cmd=$*
    local rc=0

    # If we don't have a logfile yet, discard the output
    [ -z "${logfile}" ] && logf="/dev/null"

    [ ${verbose} -gt 0 ] && echo "RUN: " ${cmd} >> ${logf}
    ${cmd}

    rc=$?

    if [ ${rc} -ne 0 ]; then
	err 1 "Failed to run ${cmd}"
    fi

    return ${rc}
}

if_up()
{
    local ip=$1
    runcmd sudo ifconfig igb0 inet alias ${ip}/16
}

if_down()
{
    local ip=$1
    runcmd sudo ifconfig igb0 inet -alias ${ip}
}

mount_proc()
{
    local rootdir=$1
    runcmd sudo mount_procfs procfs ${rootdir}/proc
}

umount_proc()
{
    local rootdir=$1
    runcmd sudo umount ${rootdir}/proc
}

mount_dev()
{
    local rootdir=$1
    runcmd sudo mount_devfs devfs ${rootdir}/dev
}

umount_dev()
{
    local rootdir=$1
    runcmd sudo umount ${rootdir}/dev
}

jail_up()
{
    local jid=0

    jid=$(jail_jid)

    #Check if jail is already running
    if [ ! -z "${jid}" ]; then
	err 1 Jail ${jid} is already running
    fi

    info Starting builder jail

    # Setup IP addresses
    if_up ${IPADDR}

    # Mount devfs
    mount_dev ${DESTDIR}

    # Mount procfs
    mount_proc ${DESTDIR}

    # Start the jail itself
    runcmd sudo -E jail ${DESTDIR} builder-buildbot ${IPADDR} /bin/sh \
	   /etc/rc

    # Jail should be running now
    jid=$(jail_jid)

    # Initial resolv.conf
    runcmd sudo cp /etc/resolv.conf ${DESTDIR}/etc/

    #
    # Customize a bit for the build process
    #
    runcmd sudo jexec ${jid} fetch \
	   --no-verify-peer https://leaf.dragonflybsd.org/~tuxillo/archive/misc/bb-jail-cust.sh
    runcmd sudo jexec ${jid} /bin/sh bb-jail-cust.sh
}

jail_down()
{
    local jid=0

    jid=$(jail_jid)

    #Check if jail is already running
    if [ -z "${jid}" ]; then
	err 1 builder-buildbot jail is not running
    fi

    info Stopping JID ${jid}

    # Kill all processes in the builder jail
    runcmd sudo jexec ${jid} /bin/kill -TERM -1 > /dev/null

    # Umount devfs
    umount_dev ${DESTDIR}

    # Umount procfs
    umount_proc ${DESTDIR}

    # Remove IP aliases
    if_down ${IPADDR}
}

jail_jid()
{
    local jid=$(jls | grep "builder-buildbot" | cut -w -f1)

    echo ${jid}
}
######## MAIN

# Sanity checks
[ -z "${DESTDIR}" ] && exit 255
[ ! -d "${DESTDIR}" ] && exit 254

case "$1" in
    "start"|"START")
	jail_up
	;;
    "stop"|"STOP")
	jail_down
	;;
    *)
	err 1 "Valid commands $0 [start|stop]"
	;;
esac

## Output logfile
#if [ ${verbose} -gt 0 ]; then
#    cat ${logfile}
#fi
