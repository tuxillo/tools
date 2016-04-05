#! /bin/sh

logfile=/tmp/bb-jail-custom.log

echo -n Setting up resolv.conf...
cat << EOF 2>/dev/null > /etc/resolv.conf
search dragonflybsd.org backplane.com
nameserver 10.0.0.25
nameserver 10.0.0.2
EOF

if [ $? -ne 0 ]; then
    echo failed!
    exit 1
else
    echo success!
fi

echo -n Testing inet connection...
if ! ping -qq -o www.google.es >> ${logfile} 2>&1; then
    echo failed!
    exit 1
else
    echo success!
fi

if [ ! -x /usr/local/sbin/pkg ]; then
    echo -n Bootstrapping pkg...

    cd /usr
    if ! make pkg-bootstrap >> ${logfile} 2>&1; then
	echo failed!
	exit 1
    else
	echo success!
    fi
fi

echo -n "Installing packages... "

if [ ! -x /usr/local/bin/git ]; then

    if ! pkg install -y git-lite >> ${logfile} 2>&1; then
	echo failed!
	exit 1
    else
	echo -n "git-lite "
    fi
fi

if [ ! -x /usr/local/bin/mkisofs ]; then

    if ! pkg install -y cdrtools >> ${logfile} 2>&1; then
	echo failed!
	exit 1
    else
	echo -n "cdrtools..."
    fi
fi

echo "success!"

if [ ! -d /usr/src ]; then
    echo -n Checking out src...

    cd /usr
    if ! make src-create-shallow >> ${logfile} 2>&1; then
	echo failed!
	exit 1
    else
	echo success!
    fi
fi

if [ ! -d /usr/dports ]; then
    echo -n Checking out dports...

    cd /usr
    if ! make dports-create-shallow >> ${logfile} 2>&1; then
	echo failed!
	exit 1
    else
	echo success!
    fi
fi

if [ ! -x /root/dobuild.sh ]; then
    echo -n Generating dobuild.sh script...
    cat <<EOF 2>/dev/null > /root/dobuild.sh
#!/bin/sh

cd /usr/src
case "\$1" in
	"release")
		cd nrelease
		make \$1
		;;
	"buildkernel"|"nativekernel")
		make -j12 \$1 KERNCONF=\$2
		;;
	"buildworld")
		make -j12 \$1
		;;
	*)
		echo Bad build option
		;;
esac
EOF

    if [ $? -ne 0 ]; then
	echo failed!
	exit 1
    else
	echo success!
    fi
fi
