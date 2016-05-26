#! /bin/sh

# General options
verbose=1
cachedir="/var/cache/dflyimg"
repository="/usr/src"
deltafile=$(mktemp)
remoteurl="https://monster.dragonflybsd.org/builds/"
imgsize=4g
imgtype="ufs"

# Commands
create=0
list=0
world=0
kernel=0
vkernel=0

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

######## HELPER FUNCTIONS
usage()
{
    err 1 "$0: -c command"
}

validate_tag()
{
    local tag=$1

    case "${tag}" in
	"worlds")
	    ;;
	"kernels")
	    ;;
	*)
	    err 1 "Invalid tag specified"
    esac
}

# Expects absolute paths
verify_checksum()
{
    local file=$1
    local tmp=""

    # Get checksum hash
    tmp=$(basename ${file})
    cksum=$(grep ${tmp} ${deltafile} | sed 's/.*= \([[:alnum:]]*\).*/\1/')

    [ -f ${file} ] || return 1

    tmp=$(md5 | sed 's/.*= \([[:alnum:]]*\).*/\1/')

    if [ "${tmp}" != "${cksum}" ]; then
	return 1
    else
	return 0
    fi
}

download_file()
{
    local tag=$1
    local file=${cachedir}/$2

    validate_tag ${tag}

    # Check if file is already in cache directory
    verify_checksum ${file}
    if [ $? -ne 0 ]; then
	rm -f ${file}
	fetch -q ${remoteurl}/${tag}/$(basename ${file}) -o ${file}
	verify_checksum ${file} || err 1 "MD5 failed for ${file}"
    fi
}

do_create()
{
    [ -z "${commitid}" ] && err 1 "No commit ID specified"

    # Make sure the correct file is being pulled
    if [ ${world} -eq 1 ]; then
	fetch_delta worlds
	# Check if the files are actually in the index
	mainfile=$(head -1 ${deltafile} | awk -F '[()]' '{print $(NF-1)}')
	x3file=$(grep \.${commitid}\. ${deltafile} | awk -F '[()]' '{print $(NF-1)}')
	[ -z "${mainfile}" ] && err 1 "Could not find base file in index."
	[ -z "${x3file}" ] && err 1 "Could not find VCDIFF file in index."

	# Get main and VCDIFF files
	download_file worlds ${mainfile}
	download_file worlds ${x3file}

    elif [ ${kernel} -eq 1 ]; then
	fetch_delta kernels
    fi

}

do_list()
{
    # A repository must be available
    [ ! -d ${repository} ] && err 1 "No repository found in ${repository}"

    # Make sure the correct file is being pulled
    if [ ${world} -eq 1 ]; then
	fetch_delta worlds
	list_commits
    elif [ ${kernel} -eq 1 ]; then
	fetch_delta kernels
	list_commits
    fi
}

list_commits()
{
    local tag=$1

    cd /usr/src
    if ! git rev-parse --is-inside-work-tree >/dev/null; then
	err 1 "Not a valid git repository at ${repository}"
    fi

    while read -r line
    do
	commit=$(echo ${line} | cut -d"." -f 5 | cut -c 2-)
	commitmsg=$(git --no-pager log -n1 --oneline ${commit} | cut -c 8-)
	if [ -z "${commitmsg}" ]; then
	    err 1 "ERROR: Please update your repository at ${repository}"
	fi
	printf " %8s %s\n" ${commit} "${commitmsg}"
    done < ${deltafile}
}

fetch_delta()
{
    local tag=$1
    local url=""

    # Make sure the correct file is being pulled
    validate_tag ${tag}

    url="${remoteurl}/${tag}/.delta.lst"

    if ! fetch -q ${url} -o ${deltafile} 2> /dev/null; then
	err 1 "No ${tag} could be found in ${url}"
    fi
}

cleanup()
{
    rm -f ${deltafile}
}

initialize()
{
    if [ `id -u` -ne 0 ]; then
	err 1 "You must be root to run this script"
    fi

    # See if needed programs are available
    if [ ! -x /usr/local/bin/git ]; then
	err 1 "Could not find git installed."
    fi

    if [ ! -x /usr/local/bin/xdelta3 ]; then
	err 1 "Could not find xdelta3 installed."
    fi

    # Need a cache directory
    [ ! -d ${cachedir} ] && mkdir -p ${cachedir}
}

######## MAIN

# Intialization tasks
initialize


while getopts ci:lwkr:qv op
do
    case $op in
	q)
	    verbose=$(( verbose - 1 ))
	    ;;
	i)
	    commitid=$OPTARG
	    ;;
	c)
	    if [ ${list} -ne 0 ]; then
		err 1 "-c and -l are incompabible"
	    fi
	    create=1
	    ;;
	l)
	    if [ ${create} -ne 0 ]; then
		err 1 "-c and -l are incompabible"
	    fi
	    list=1
	    ;;
	w)
	    world=1
	    ;;
	k)
	    kernel=1
	    ;;
	r)
	    repository=$OPTARG
	    ;;
	v)
	    vkernel=1
	    ;;
	*)
	    usage
    esac
done

# Shift the arguments to be able to use the parameters that are not options
shift $(($OPTIND - 1))

if [ ${create} -eq 1 ]; then
    do_create
elif [ ${list} -eq 1 ]; then
    do_list
else
    err 1 "Bad options specified."
fi

# Cleanup temporary files
#cleanup
