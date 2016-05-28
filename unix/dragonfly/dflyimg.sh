#! /bin/sh
#
# Copyright (c) 2016 The DragonFly Project.  All rights reserved.
#
# This code is derived from software contributed to The DragonFly Project
# by Antonio Huete <tuxillo@quantumachine.net>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
# 3. Neither the name of The DragonFly Project nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific, prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
# COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# set -x

# General options
remoteurl="https://monster.dragonflybsd.org/builds"

verbose=1
cachedir="/var/cache/dflyimg"
repository="/usr/src"
destdir=""
deltafile=$(mktemp)
imgsize=2g
imgfile=""
vndev=""

# Commands
create=0
list=0
option=""
image=0

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
    local redir=""
    local cmd=$*
    local rc=0

    # If we don't have a logfile yet, discard the output
    [ ! -z "${logfile}" ] && redir=">> ${logfile}"

    [ ${verbose} -gt 1 ] && echo "RUN: " ${cmd} ${redir}
    ${cmd} ${redir}

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

    #
    # Whenever the the passed file is not found o the checksum could not be
    # retrieved, return error
    #
    [ -f ${file} ] || return 1
    [ ! -z "${cksum}" ] || return 1

    tmp=$(md5 ${file} | sed 's/.*= \([[:alnum:]]*\).*/\1/')

    info "Checking integrity: ${file} ( ${cksum} / ${tmp} )"

    if [ "${tmp}" != "${cksum}" ]; then
	return 1
    else
	return 0
    fi
}

download_file()
{
    local tag=$1
    local verify=$2
    local file=${cachedir}/$3
    local url="${remoteurl}/${tag}/$(basename ${file})"

    validate_tag ${tag}

    # Check if file is already in cache directory

    [ -f ${file} ] && info "Found file $(basename ${file}) in cache."

    [ ${verify} -eq 1 ] && verify_checksum ${file}
    if [ $? -ne 0 ]; then
	runcmd rm -f ${file}
	info "Fetching ${url}"
	runcmd fetch -q ${url} -o ${file}
	if [ ${verify} -eq 1 ]; then
	    verify_checksum ${file} || err 1 "MD5 failed for ${file}"
	fi
    fi
}

# Exits 0 if found
is_mounted()
{
    local fs=$1
    local found=1

    info "Checking if ${fs} is mounted"

    for mp in `df -P | cut -w -f6`
    do
	if [ "${fs}" == "${mp}" ]; then
	    found=0
	    break
	fi
    done

    return ${found}
}

create_image()
{
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local tmpfile=$(mktemp)

    is_mounted ${cachedir}/root && err 1 "${cachedir}/root is already mounted."

    # Find an unused vn device
    vndev=$(vnconfig -l | fgrep "not in use" | cut -f 1 -d : | head -1)

    [ -z "${vndev}" ] && err 1 "Could not find a VN device available"

    #
    # Create the image file. It will also fdisk the virtual device
    # and attempt to create a very basic label which includes a small
    # swap and a single UFS partition.
    #
    imgfile="${cachedir}/tmp/root.${timestamp}.img"

    runcmd vnconfig -c -T -S ${imgsize} -s labels ${vndev} ${imgfile}
    runcmd fdisk -IB ${vndev} >/dev/null
    runcmd disklabel -r -w ${vndev}s1 auto
    runcmd disklabel -r ${vndev}s1 > ${tmpfile}

    echo 'a: * * 4.2BSD' >> ${tmpfile}
    echo 'b: 128M * swap' >> ${tmpfile}

    runcmd disklabel -R ${vndev}s1 ${tmpfile}
    runcmd disklabel -B ${vndev}s1

    runcmd newfs /dev/${vndev}s1a > /dev/null
    runcmd vnconfig -u ${vndev}

    rm ${tmpfile}
}

mount_img()
{
    runcmd vnconfig ${vndev} ${imgfile}
    runcmd mount /dev/${vndev}s1a ${cachedir}/root 2>/dev/null
}

umount_img()
{
    runcmd umount ${cachedir}/root 2>/dev/null
    runcmd vnconfig -u ${vndev}
}

create_world()
{
    local targetdir=$1

    [ -d "${targetdir}" ] || err 1 "Cannot access destdir ${targetdir}"

    info "Creating world from commit: ${commitid}"

    fetch_delta worlds

    # Check if the files are actually in the index
    mainfile=$(head -1 ${deltafile} | awk -F '[()]' '{print $(NF-1)}')
    x3file=$(grep \.${commitid}\. ${deltafile} | awk -F '[()]' '{print $(NF-1)}')
    [ -z "${mainfile}" ] && err 1 "Could not find base file in index."
    [ -z "${x3file}" ] && err 1 "Could not find VCDIFF file in index."

    # Get main and VCDIFF files
    download_file worlds 1 ${mainfile}
    download_file worlds 0 ${x3file}.vcdiff

    #
    # If the assembled file already exist, verify the MD5 signature. Otherwise
    # just try to assemble it.
    #
    if [ -f ${cachedir}/${x3file} ]; then
	info "Found ${cachedir}/${x3file} in cache."
	verify_checksum ${cachedir}/${x3file}
	[ $? -ne 0 ] && err 1 "Failed checksum for ${x3file}"
    else
	info "Assembling file ${cachedir}/${x3file}"
	runcmd xdelta3 -d -s ${cachedir}/${mainfile} \
	       ${cachedir}/${x3file}.vcdiff ${cachedir}/${x3file}
	verify_checksum ${cachedir}/${x3file}
	[ $? -ne 0 ] && err 1 "Failed checksum for ${x3file}"
    fi

    #
    # Unpack tar file to destination directory. Check if the directory
    # is empty to avoid overwriting already existing worlds.
    #
    [ "$(ls -A ${targetdir})" ] && err 1 "${targetdir} is not empty."
    tar --strip-components 7 -xpf ${cachedir}/${x3file} -C ${targetdir}

    if [ $? -eq 0 ]; then
	info "World ready at ${targetdir}"
	echo ${targetdir}
    else
	err 1 "Failed to unpack ${cachedir}/${x3file} in ${targetdir}"
    fi
}

do_create()
{

    # Sanity checks
    [ -z "${commitid}" ] && err 1 "No commit ID specified"

    case "${option}" in
	"world")
	    if [ ${image} -eq 1 ]; then
		create_image

		mount_img

		destdir=${cachedir}/root
		create_world ${destdir}

		umount_img
	    else
		[ -z "${destdir}" ] && err 1 "A destination directory must be specified"
		create_world ${destdir}
	    fi
	    ;;

	"kernel")
	    err 1 "Not implemented"
	    ;;

	*)
	    err 1 "Unexpected error"
    esac

}

do_list()
{
    # A repository must be available
    [ ! -d ${repository} ] && err 1 "No repository found in ${repository}"

    # Make sure the correct file is being pulled
    case "${option}" in
	"world")
	    fetch_delta worlds
	    list_commits
	    ;;
	*)
	    err 1 "Unimplemented"
    esac
}

list_commits()
{
    local tag=$1

    cd ${repository}
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

    info "Fetching ${url}"

    runcmd fetch -q ${url} -o ${deltafile} 2> /dev/null
    if [ $? -ne 0 ]; then
	err 1 "No ${tag} could be found in ${url}"
    fi
}

cleanup()
{
    runcmd rm -f ${deltafile}
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

    # Need a few directories in cachedir
    [ ! -d ${cachedir} ] && mkdir -p ${cachedir}
    [ ! -d ${cachedir}/root ] && mkdir -p ${cachedir}/root
    [ ! -d ${cachedir}/tmp ] && mkdir -p ${cachedir}/tmp
}

######## MAIN

# Intialization tasks
initialize


while getopts cd:i:lwkr:mqvz op
do
    case $op in
	v)
	    verbose=$(( verbose + 1 ))
	    ;;
	q)
	    verbose=$(( verbose - 1 ))
	    ;;
	i)
	    commitid=$OPTARG
	    ;;
	d)
	    destdir=$OPTARG
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
	    if [ -n "${option}" ]; then
		err 1 "-k option has been already specified"
	    fi
	    option="world"
	    ;;
	k)
	    if [ -n "${option}" ]; then
		err 1 "-w option has been already specified"
	    fi
	    option="kernel"
	    ;;
	r)
	    repository=$OPTARG
	    ;;
	m)
	    image=1
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
