#!/bin/bash


#######################################################################################
#
#   Script that automatically launches the local Virsh/qemu based VM
#   
#   Created by - Maciej 'Smirk' Blachnio 2015.07
#
#	This program is under GPL [http://www.gnu.org/licenses/gpl.html]
#
#   Modify the following to match your configuration
#	Vars: machine, network, username and dirname
#
#   Obviously you need to place it in some autostart location, 
#   you will also need SUDO privileges for the commands below.
#
#######################################################################################

# The name of the VM to start
machine="Win7"
# The name of the network assigned to the VM
network="default"
# Your username, set if your path below requires it (and you need qemu permissions to it)
username="somelocaluser"
# The folder in which the VM image resides
dirname="/run/media/${username}/SOMEPATH"
cnt=0

# Wait up to 30s for the default router and the path specified above to appear
until [[ "${cnt}" -eq 30 || ( -n "$(ip ro|grep default)" && -d "${dirname}" ) ]]
do
	let cnt++
	sleep 1
done
echo test1
# Check if you finally have a default router (you usually need one when working on the net :) )
[ -z "$(ip ro|grep default)" ] && ( logger "Default router not found. Check your network configuration"; exit 1 )
echo test2

# Determine if the folder name set in the variable above is correct
[ ! -d "${dirname}" ] && ( logger "${machine} image cannot be located. Check for the existence of ${dirname}"; exit 1 )

# Determine the local default router IP (I assume here it's going to be the main DNS for the vm)
dns="$(ip ro|grep "default.* "|sed 's/default via //;s/ .*//')"

# Spit out an error if the address cannot be found
[ ! "${dns}" ] && ( logger "No DNS/default router IP found. Check your network configuration."; exit 1 )

## Proceed with further steps of launching the VM
# Recreate the VM network config file with the current default gw
sudo rm -f /tmp/${network}.xml
sudo virsh net-dumpxml --inactive ${network} > /tmp/${network}.xml
sudo virsh net-destroy ${network}
sudo sed -i'' "s/forwarder addr=.*/forwarder addr='${dns}'\/>/" /tmp/${network}.xml
sudo virsh net-define /tmp/${network}.xml
sudo virsh net-start ${network}
sudo rm -f /tmp/${network}.xml

# Build a folder tree and change its permissions accordingly (a hack really, but it's simpler this way)
paths=($(for dir in $(echo ${dirname}|sed 's/\// /g');do path="${path}/${dir}";echo -n "${path} ";done))
for dir in $(echo ${paths[@]:1})
do
	sudo setfacl -R -m u:qemu:rwx ${dir}
done

sudo setfacl -R -m u:qemu:rwx ${dirname}/${machine}

[ -n "${username}" ] && sudo setfacl -R -m u:${username}:rwx ${dirname}/${machine}

sudo virsh start ${machine}

