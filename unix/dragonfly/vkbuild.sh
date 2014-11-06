#! /bin/sh
#set -x

REPOSITORY=${REPOSITORY:=/usr/src}
ARCH=""
NCPU=`sysctl hw.ncpu | cut -w -f 2`
COPTFLAGS="-g -O0"
export COPTFLAGS

usage()
{
	echo `basename $0`: '[buildkernel|quickkernel|nativekernel]'
	echo 'Make sure you set VKDIR environment variable to your VKERNEL path'
	echo 'REPOSITORY environment variable points to /usr/src by default.'
	exit 255
}

do_build()
{
    local _ret
    local buildmode=$1
    local arch=$2

    cd ${REPOSITORY}
    make -j${NCPU} ${buildmode} -DNO_MODULES KERNCONF=VKERNEL${arch} \
	> /tmp/buildkernel_${ACTION}.log 2>&1

    if [ $? -ne 0 ]; then
	echo Failed to build, please check /tmp/buildkernel_${ACTION}.log
	exit 1
    else
	echo "    + Installing vkernel into ${VKDIR}"
	sudo sh -c "make installkernel DESTDIR=${VKDIR} -DNO_MODULES KERNCONF=VKERNEL${arch}" > /tmp/buildkernel_${ACTION}.log2 >&1
    fi
}

get_arch()
{
    if [ "`uname -m`" = "i386" ]; then
	ARCH=""
    else
	ARCH="64"
    fi
}

# ---------------------------------------------------------------
get_arch
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
		echo --- Action: ${ACTION} config file: VKERNEL${ARCH}
		do_build ${ACTION} ${ARCH}
		;;
	*)
		usage
		;;
esac
