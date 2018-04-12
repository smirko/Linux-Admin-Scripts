#!/bin/bash


#######################################################################################
#
#   Script that automatically launches the local Virsh/qemu based VM
#   
#   Created by - Maciej 'Smirk' Blachnio 2015.07 (with later changes)
#
#	This program is under GPL [http://www.gnu.org/licenses/gpl.html]
#
#   Modify the following to match your configuration
#	Vars:
#		 	- machine (passed as script argument of vmname), \
#			- network, \
#			- username, \
#			- dirname (passed as script argument of vmpath)
#
#	Environment / host dependent:	
#			- USB controller ID from lspci (ctrlID) \
#			- Vendor / Product IDs (venID, prdID)
#
#   Obviously you need to place it in some autostart location, 
#   you will also need SUDO privileges for the whole script.
#
#	It's possible that you'll need to change the default virbr0 name 
#	to suit your environment
#
#######################################################################################

errmsg="Usage: $0 -vmname VM_NAME_IN_VMM -vmpath PATH_TO_VM_IMAGE_FILE [-rescon 0|1]"


[ $# -lt 4 ] && echo ${errmsg} && exit 1

while [ "$1" != "${1##[-+]}" ]; do
  case $1 in
    '')    echo ${errmsg}
           return 1;;
    -vmname)
           vmname="$2"
           shift 2
           ;;
    -vmpath)
           vmpath="$2"
           shift 2
           ;;
    -rescon)
           rescon=$2
           shift 2
           ;;
    *)     echo ${errmsg}
           return 1;;
  esac
done


# The name of the VM to start (script argument)
machine="${vmname}"
# The path to the VM file (script argument)
diskimg="$(basename "${vmpath}")"
# The name of the network assigned to the VM
network="default"
# Your username, set if your path below requires it
username="USERNAME"
ctrlID="0000:00:1a.0"
venID="8086"
prdID="1e2d"

IFS=""
dirname="$(dirname ${vmpath})"
IFS=" "
cnt=0

# UNBIND USB2 CONTROLLER (MY HOST TENDS TO HANG WITHOUT IT, you'll surely need to put your own USB controller ID from lspci + Vendor / Product IDs below)
if [ ! "$(ps -ef |grep [q]emu)" ]
then
	# Reset the USB controller driver if required
	if [[ "${rescon}" && "${rescon}" -eq 1 ]]
	then
		modprobe -r vfio_pci 2>/dev/null
		modprobe -r vfio_iommu_type1 2>/dev/null
		modprobe vfio_pci
		echo "${ctrlID}" |tee /sys/bus/pci/drivers/ehci-pci/unbind 2>/dev/null
		echo "${venID}" "${prdID}" |tee /sys/bus/pci/drivers/vfio-pci/new_id
	fi
	## Proceed with further steps of launching the VM
	# Recreate the VM network config file with the current default gw
	brctl delif virbr0 vnet0 2>/dev/null
	brctl delif virbr0 virbr0-nic 2>/dev/null
	ifconfig virbr0 down
	brctl addif virbr0 virbr0-nic
	ifconfig virbr0 up
	rm -f /tmp/${network}.xml
	virsh net-dumpxml --inactive ${network} > /tmp/${network}.xml
	virsh net-destroy ${network}
	# Determine the local default router IP (I assume here it's going to be the main DNS for the vm)
	dns="$(ip ro|grep "default.* "|sed 's/default via //;s/ .*//')"

	# Spit out an error if the address cannot be found
	[ ! "${dns}" ] && ( logger "No DNS/default router IP found. Check your network configuration."; exit 1 )

	sed -i'' "s/forwarder addr=.*/forwarder addr='${dns}'\/>/" /tmp/${network}.xml
	virsh net-define /tmp/${network}.xml
	virsh net-start ${network}
	rm -f /tmp/${network}.xml
fi
# Wait up to 30s for the default router and the path specified above to appear
until [[ "${cnt}" -eq 30 || ( -n "$(ip ro|grep default)" && -d "${dirname}" ) ]]
do
	let cnt++
	sleep 1
done

# Check if you finally have a default router (you usually need one when working on the net :) )
[ -z "$(ip ro|grep default)" ] && ( logger "Default router not found. Check your network configuration"; exit 1 )

# Determine if the folder name set in the variable above is correct
[ ! -d "${dirname}" ] && ( logger "${machine} image cannot be located. Check for the existence of ${dirname}"; exit 1 )

# Build a folder tree and change its permissions accordingly (a hack really, but it's simpler this way)

paths=($(for dir in $(echo "${dirname}"|sed 's/\// /g');do path="${path}/${dir}";echo -n "${path} ";done))
for dir in $(echo ${paths[@]:1})
do
	setfacl -m u:qemu:rwx ${dir}
done
setfacl -m u:qemu:rwx ${dirname}
setfacl -R -m u:qemu:rwx ${dirname}/${diskimg}

sed -i'' "s+<source file='.*'/>+<source file='${vmpath}'/>+" /etc/libvirt/qemu/${vmname}.xml

service libvirtd reload

IFS=""
[ -n "${username}" ] && setfacl -R -m u:${username}:rwx ${dirname}/${diskimg}
IFS=" "
virsh start ${machine}

