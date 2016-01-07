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

#! /bin/sh

dports_dir=/usr/dports
configfile="dports.conf"
catprefix=""
wrkdir=
logdir=
logfile=
tgtdir=
distdir=
mkenvvars=
maxwidth=16
npkg=0
rmprev=0
verbose=0
success=0
failed=0
skipped=0
starttime=""

# All categories
categories="vietnamese hebrew hungarian arabic x11-servers x11-drivers ukrainian x11-clocks benchmarks russian portuguese german converters accessibility news ftp ports-mgmt polish shells archivers x11-fm astro chinese x11-fonts comms net-p2p dns french finance biology irc korean net-im cad science x11-wm emulators japanese multimedia editors x11 x11-toolkits net-mgmt deskutils audio databases math textproc mail net misc sysutils graphics games x11-themes security print lang devel java www"


#
# info message
# 	Display an informational message, typically under
#	verbose mode.
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
# 	Execute a command
runcmd()
{
    local logf=${logfile}
    local cmd=$*

    # If we don't have a logfile yet, discard the output
    [ ! -f ${logfile} ] && logf="/dev/null"

    [ ${verbose} -gt 0 ] && echo "RUN: " ${cmd} >> ${logf}
    ${cmd} >> ${logf} 2>&1

    return $?
}

#
# countpkg category
# 	Counts all packages to be processed
countpkg()
{
    npkg=0

    # Iterate allowed categories and count all directories
    # and while here specify maximum width
    for dir in ${dports_dir}/${category}/*
    do
	if [ -d ${dir} ]; then
	    npkg=$(( npkg + 1 ))
	    tmp=$(echo ${dir} | wc -c)
	    if [ ${tmp} -gt ${maxwidth} ]; then
		maxwidth=${tmp}
	    fi
	fi
    done
}

#
# clean_previous
#
clean_previous()
{
    #
    # Cleanup tgtdir and logdir only, if requested
    # Normally it makes no sense to remove distdir
    info "Cleaning up prior executions."
    for category in ${categories}
    do
	rm -fr ${tgtdir}/${catprefix}${category}
    done

    rm -fr ${logfile}
    rmdir ${logdir} 2>/dev/null
}

#
# setup
# 	Do some initial tasks required for dports extraction
setup()
{
    local mkdir_flags="-p"
#    local timestamp=$(date +'%Y%m%d%H%M%S')

    # Load configuration file
    [ -f "${configfile}" ] && . ${configfile}

    # Directories and flag setup
    wrkdir=${wrkdir:-$HOME/temp/dports}
    tgtdir=${tgtdir:-${wrkdir}/extracted}
    logdir=${logdir:-${wrkdir}/log}
    logfile=${logfile:-${logdir}/extraction.log}
    distdir=${distdir:-${wrkdir}/distdir}

    [ ${verbose} -gt 0 ] && mkdir_flags=${mkdir_flags}" -v"

    if [ ${rmprev} -gt 0 ]; then
	clean_previous
    fi

    info "Creating directory for the extraction: "${wrkdir}
    for dir in ${wrkdir} ${tgtdir} ${logdir} ${distdir}
    do
	[ ! -d ${dir} ] && ( runcmd mkdir ${mkdir_flags} ${dir} || \
		err 255 "Unable to create ${dir}" )
    done

    # Make sure logfile exists
    touch ${logfile}

    # Make specific environment variables
    mkenvvars="WRKDIRPREFIX=${tgtdir} DISTDIR=${distdir} BATCH=yes"

    # Enforce LANG C to avoid sed problems
    export LANG=C

    # Start time
    starttime=`date`
}

#
# cleanup
# 	A little cleanup
cleanup()
{
    # Post-extraction cleanup
}

postprocess_pkg()
{
   local dir=$1

   #
    # Remove all files that are deemed useless. Also
    # remove .gz files *temporarily* because there is a
    # bug either in openjdk on in the gzip parser that
    # causes a crash in the indexing process.
    runcmd find ${dir} \( \
	   -iname "*.gz" -o \
	   -iname "*.log" -o \
	   -iname "*.bak" -o \
	   -iname "*.orig" -o \
	   -iname "*.orig" -o \
	   -iname "*.rej" \) -delete

    #
    # Directories not accessible must be to allow browsing
    #
    runcmd find ${dir} -type d \( \
	   -perm 0700 -o \
	   -perm 0750 \) \
	   -exec chmod 755 {} \;

    #
    # Many files are left either with 0400 or 0600 perms
    # and that has to be changed so browsing through the
    # files is possible.
    runcmd find ${dir} -type f \( \
	   -perm 0400 -o \
	   -perm 0600 -o \
	   -perm 0640 -o \
	   -perm 0660 \) \
	   -exec chmod 644 {} \;

}

#
# process_category category
# 	Do the actual tasks required for dports extraction/patching
process_category()
{
    local category=$1
    local count=1
    local work_dir=""
    local src=""
    local tgt=""

    countpkg ${category}	# Sum up all elements to be processed
    for dir in ${dports_dir}/${category}/*
    do
	if [ -d ${dir} ]; then
	    # Advertise which package we're handling
	    [ ${verbose} -gt 0 ] && \
		printf "  ==> %-${maxwidth}s [%d/%d]\n" ${dir} ${count} ${npkg}

	    # Actual processing
	    # 	1. Change to port dir
	    #	2. Cleanup if requested
	    #	3. Perform 'make patch' on each port
	    #	4. Move our WRKSRC to the tgtdir
	    #	5. Remove all *.log *.bak *.orig *.rej
	    #	6. Dispose "work" directory

	    # Deal with work and WRKSRC
	    runcmd cd ${dir} || err 1 "cd to ${dir}"
	    src=$(make ${mkenvvars} -VWRKSRC)
	    tgt=${tgtdir}/${category}/${dir##*/}
	    work_dir=$(make ${mkenvvars} -VWRKDIR)

	    if [ ! -d  ${src} ]; then
		# XXX This doesn't keep old package versions in place
		runcmd make ${mkenvvars} rmconfig && \
		    runcmd make ${mkenvvars} clean && \
		    runcmd make ${mkenvvars} patch

		if [ $? -ne 0 ]; then
		    failed=$(( failed + 1 ))
		else
		    success=$(( success + 1 ))

		    # Post processing
		    postprocess_pkg ${src}
		fi
	    else
		info "Skipping existing ${src}" >> ${logfile}
		skipped=$(( skipped + 1 ))
	    fi

	    # Next port
	    count=$(( count  + 1 ))
	fi
    done

    # Rename the category if necessary
    if [ ! -z "${catprefix}" ]; then
	runcmd mv ${tgtdir}/${category} ${tgtdir}/${catprefix}${category}
    fi
}

#
# STATS -
stats()
{
    local total=$(( success + failed + skipped ))

    echo "--------------------------------------------------------------"
    echo " >>> Started on ${starttime}"
    echo " >>> Ended on   `date`"
    echo " >>> Total=${total} OK=${success} FAIL=${failed} SKIP=${skipped}"
    echo "--------------------------------------------------------------"
}

#
# USAGE -
usage()
{
    exitval=${1:-1}
    echo "Usage: ${0##*/} [-hrkv] [-w wrkdir] [-d distdir]" \
    "[-t tgtdir] [-l logdir] [-p catprefix] [-c cfgfile]"
    exit $exitval
}

# ---------------------------------
# Handle options
while getopts hrw:d:t:p:l:c:v op
do
    case $op in
	v)
	    verbose=1
	    ;;
	c)
	    configfile=$OPTARG
	    ;;
	r)
	    rmprev=1
	    ;;
	w)
	    wrkdir=$OPTARG
	    ;;
	d)
	    distdir=$OPTARG
	    ;;
	p)
	    catprefix=$OPTARG
	    ;;
	t)
	    tgtdir=$OPTARG
	    ;;
	l)
	    logdir=$OPTARG
	    ;;
	h)
	    usage 0
	    ;;
	*)
	    usage
	    ;;
    esac
done

shift $(($OPTIND - 1))

# Make sure we have what we need to begin!
setup

# Iterate allowed categories
for category in ${categories}
do
    info "Working on category" ${category}
    process_category ${category}
done

# Cleanup
cleanup

# Print stats
stats
