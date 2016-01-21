#! /bin/sh
#
# This script is work in progress
#
#set -x

KCONF=${KERNCONF:=VKERNEL64}
REPOSITORY=${REPOSITORY:=/usr/src}
NCPU=`sysctl hw.ncpu | cut -w -f 2`
COPTFLAGS="-g -O0"
export COPTFLAGS

usage()
{
	echo `basename $0`: '[buildkernel|quickkernel|nativekernel]'
	echo 'Make sure you set VKDIR environment variable to your VKERNEL path'
	echo 'REPOSITORY environment variable points to /usr/src by default.'
	echo 'KERNCONF environment variable is VKERNEL64 by default.'
	exit 255
}

do_build()
{
    local _ret
    local buildmode=$1

    cd ${REPOSITORY}
    make -j${NCPU} ${buildmode} -DNO_MODULES KERNCONF=${KCONF} \
	> /tmp/buildkernel_${ACTION}.log 2>&1

    if [ $? -ne 0 ]; then
	echo Failed to build, please check /tmp/buildkernel_${ACTION}.log
	exit 1
    else
	echo "    + Installing vkernel into ${VKDIR}"
	if $(which sudo>/dev/null); then
	    sh -c "make installkernel DESTDIR=${VKDIR} -DNO_MODULES KERNCONF=${KCONF}" > /tmp/buildkernel_${ACTION}.log2 >&1
	else
	    kfile=$(make -V .OBJDIR)/sys/${KCONF}/kernel.debug
	    if [ ! -d ${VKDIR}/boot/kernel ]; then
		mkdir -p ${VKDIR}/boot/kernel
	    fi
	    cp ${kfile} ${VKDIR}/boot/kernel/vkernel
	fi
    fi

    # Make sure the symlink exists
    if [ ! -L ${VKDIR}/vkernel ]; then
	ln -sf ${VKDIR}/boot/kernel/vkernel ${VKDIR}/vkernel
    fi
}

# ---------------------------------------------------------------
ACTION="$1"

if [ $# -ne 1 ]; then
	usage
fi

if [ "${VKDIR}" = "" ]; then
    usage
fi

if [ ! -d ${VKDIR} ]; then
	echo ${VKDIR} directory does not exist.
	exit
fi

case $1 in
	'buildkernel'|'quickkernel'|'nativekernel')
		echo --- Action: ${ACTION} config file: ${KCONF}
		do_build ${ACTION}
		;;
	*)
		usage
		;;
esac
