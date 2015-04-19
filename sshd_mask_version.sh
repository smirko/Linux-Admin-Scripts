#!/bin/bash


################################################################################
#
#	This script masks your SSH server version and by that
#	makes it a little less vulnerable. It's harder to break into
#	something you know little about.
#
#   	Created by Maciej 'Smirk' Blachnio - 2015
#
#	This program is under GPL [http://www.gnu.org/licenses/gpl.html]
#
#	This script takes no parameters, the only variable is 'fullauto'
#	which can have a value of 0 or 1
#
################################################################################



# Change this to 1 if you don't want any questions asked
# (and  lose the opportunity to have a unique SSH server version ;-) )
fullauto=0

# Make a backup copy of the original sshd binary
cp $(which sshd) /tmp/
cd /tmp

if [ "$(which wget &>/dev/null;echo $?)" -ne 0 ]
then
	echo "You need wget for this script to work."
	echo "Install it or add it to your path, then rerun the script."
	exit 1
fi

if [ ${fullauto} -eq 0 ]
then
	# Ask the user to provide the current version of OpenSSH server 
	# (manual intervention gives the user a little understanding of whats going on, if you want complete automation, set fullauto to 1 at the beginning)
	echo "Manual mode requested"
	echo
	echo "You should see your OpenSSH version below"
	echo
	wget -O- -T1 -t1 localhost:22 2>&1|grep "^SSH"
	echo
	echo "Type or paste the exact OpenSSH version read above, e.g. OpenSSH_6.6.1 (omit the leading SSH-2.0- or so)"
	echo "If you can't see anything above, try to read the version by issuing: \"telnet localhost 22\" from the terminal"
	echo
	echo -n "Put the version here and hit ENTER: "
	read ver
else
	echo "Automatic mode requested"
	s=$(wget -O- -T1 -t1 localhost:22 2>&1|grep "^SSH")
	dl=$(echo $[ ${#s} - 1 ])
	# Iterate through the string to avoid problems with invisible characters in the returned version
	for (( i=0; i<${dl}; i++ ))
	do
		ver="$ver${s:$i:1}"
	done
	ver=$(echo ${ver}|sed "s/SSH-2.0-//")
fi

# Look for our current OpenSSH binary version (ver) and starting byte (start)
str=$(strings -t d -a -n 7 sshd|grep -m1 " ${ver}$")
start=$(echo $str|cut -d' ' -f1)
echo
echo -e "Version's starting position in binary\t:${start}"

# Find the length of provided version string
dl=$(echo ${#ver})
echo -e "Length of the string provided\t\t:${dl}"
echo

# See if the part of the binary that we pointed to above contains the correct string 
# MUST equal ${ver} (DEBUGGING PURPOSES ONLY, uncomment below if needed)
#dd if=./sshd bs=1 skip=${start} count=${dl} | od -A n -c

echo "Creating first part of the binary"
if [ -f sshd ]
then
	dd if=./sshd bs=1 count=${start} of=sshd.1 &>/dev/null
else
	echo "Couldn't find sshd binary, exiting"
	exit 1
fi
if [ ${fullauto} -eq 0 ]
then
	echo "Creating second part from the user-provided string"
	echo "Please type a string of length ${dl} (zeroes mark tens)"
	echo "1#######10########20########30########40"
	read emblem
else
	cnt=0
	echo "Creating second part with default masking string"
	while [ "${cnt}" -lt "${dl}" ]
	do
		emblem="${emblem}#"
		let cnt++
	done
fi
echo -n "${emblem}" > sshd.2

echo "Creating the last part"
dd if=./sshd bs=1 skip=$[ ${dl} + ${start} ] count=999999999 of=sshd.3 &>/dev/null

echo
echo "Concatenating the parts into destination binary"
cat sshd.1 sshd.2 sshd.3 > sshd.new
chmod 755 ./sshd.new

echo
echo "Checking if your new binary is ready (you should now be able to see your new version with the custom string)"
sudo /tmp/sshd.new -D -p 2222 -o ListenAddress=localhost &
sleep 1
wget -O- -T1 -t1 localhost:2222 2>&1|grep SSH
res=$?

# Exit any instances of your new binary 
sudo killall sshd.new 2>/dev/null
echo
if [ ${res} -eq 0 ]
then
	echo "OK! You should be good to go with replacing the original $(which sshd) with /tmp/sshd.new now"
	# Uncomment only if you know what you're doing
	# THIS IS GOING TO REPLACE YOUR ORIGINAL BINARY
	# IF SSH IS YOUR ONLY WAY OF ACCESSING THIS SYSTEM, YOU MIGHT LOCK YOURSELF OUT IF THE PROCEDURE DID NOT WORK AS PLANNED
	#if [ ${fullauto} -eq 0 ]
	#then
	#	scp /tmp/sshd.new $(which sshd)
	#	echo "You need to restart your ssh server now for the changes to take effect."
	#fi
else
	echo "ERROR! Something went wrong, your binary is not listening as it should, try again"
fi

echo "Goodbye!"
echo

