#! /bin/sh
#set -x

verbose=0
dolist=0

#
# info message
# 	Display an informational message, typially under
#	verbose mode.
info()
{
    local msg=$1
    shift

    [ ${verbose} -gt 0 ] && echo "INFO: " ${msg} $*
}

#
# USAGE -
usage()
{
    exitval=${1:-1}
    echo "Usage: ${0##*/} [-v] command"
    exit $exitval
}

find_vkernel_pid()
{
    local vkidx=$1
    local tmp=""
    local ret=""
    local i=0

    for vkernel in `pgrep kernel | sort`
    do
	tmp=$(pgrep -P ${vkernel})
	[ -z "${tmp}" ] && continue

	if [ ${i} -eq ${vkidx} ]; then
	    ret=${tmp}
	    break
	fi
	i=$(( $i + 1 ))
    done

    echo ${ret}
}

list_all()
{
    local p=""
    local n=0

    printf "VKERNEL       PID\n"
    while true
    do
	p=$(find_vkernel_pid ${n})
	[ -z "${p}" ] && break

	printf "%2d\t%9d\n" ${n} ${p}

	n=$(( ${n} + 1 ))
    done
}

run_for_vkernel()
{
}

# ---------------------------------
# Handle options
while getopts vl op
do
    case $op in
	v)
	    verbose=1
	    ;;
	l)
	    dolist=1
	    ;;
	*)
	    usage
	    ;;
    esac
done

shift $(($OPTIND - 1))

vkidx=$1
cmd=$2

if [ ${dolist} -eq 1 ]; then
    list_all
    exit 0
fi

if [ $# -lt 2 ]; then
    usage
fi

vkpid=$(find_vkernel_pid ${vkidx})
info "VKERNEL ${vkidx} PID ${vkpid}"
shift 2
[ ! -z "${vkpid}" ] && ${cmd} -N /proc/${vkpid}/file -M /proc/${vkpid}/mem $@
