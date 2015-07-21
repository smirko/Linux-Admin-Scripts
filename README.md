# sshd_mask_version.sh
A script that simplified my everyday work as a Linux administrator

Ever wanted to hide your SSH server version from the emblem when somebody connects to it?

I've recently noticed a lot of sshd version gathering traffic coming from the internet
and wanted to make this task a little harderi for the bots and their masters.
This little script helps you do just that. It prevents sshd from introducing itself too
eagerly.

BEWARE! You need to know what you're doing before you replace the original sshd system binary.
There might be some circumstances (e.g. SELinux in enforcing mode) when the reworked binary 
is going to work during the test and fail in real environment. But if you're using SELinux 
in enforcing I'm sure you know how to handle it.

Other than that it's easy as pie. You just need any Linux distro using sshd binary as your 
OpenSSH server and some system privileges to place the reworked binary back into the original directory.

So far tested under Fedora and Debian.

# keepalive_ints.sh
Script to watch for remote host availability that:
	- restarts interfaces specified
	- reloads their kernel modules
	- reboots the device if none of the above helps

WARNING! You should know what you're doing, as remote WAN hosts tend 
		 to become unavailable for reasons other than local interface issues.
		 It's probably best to point your probes at hosts directly connected
		 to the same infrastructure as the host you run this script on

# start_virtual.sh
Ever wanted to autostart a Qemu VM, but it kept throwing lots of errors and died? 
Well. I did. So I wrote this little workaround script that solves some of the problems I faced.

Cheers
Smirk
