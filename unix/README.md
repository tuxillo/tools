unix
=====

* common/git-remote-updater:

A simple script to update git repositories:

    antonioh@andromeda:~$ git-repo-updater -h
    Usage: git-repo-updater [-hVvk] [-d <root data directory>]
           -h            Shows usage.
           -V            Print script version and exit.
           -v            Be verbose.
           -k            Force updating ssh remotes.
           -p            Pull after updating remotes.
    NOTE: If you force updating ssh remotes a password prompt may appear
          and thus not suitable for scripts.
          Also note that even though -p is specified, pulls won't occur
          if the repo is not in clean state. -r is specified with pulls


* dragonfly/vkbuild.sh

A script that helps building DragonFly BSD vkernels.
It requires sudo to perform a make install, it needs a directory where to store the kernel file and it only takes care of the kernel part.

    antonioh@andromeda:/s/tools$ vkbuild.sh
    vkbuild.sh: [buildkernel|quickkernel|nativekernel]
    Make sure you set VKDIR environment variable to your VKERNEL path
    REPOSITORY environment variable points to /usr/src by default.

    antonioh@andromeda:/s/tools$ env REPOSITORY=/s/dfbsd VKDIR=/vkernel/vk01 vkbuild.sh buildkernel
    --- Action: buildkernel config file: VKERNEL64
    + Installing vkernel into /vkernel/vk01

