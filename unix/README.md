unix
=====

* common/git-remote-update:

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
