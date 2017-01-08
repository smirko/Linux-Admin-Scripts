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

errmsg="Usage: $0 -vmname VM_NAME_IN_VMM -vmpath PATH_TO_VM_IMAGE_FILE [-rescon 0|1]"
#st="^\-"


[ $# -lt 4 ] && echo ${errmsg} && exit 1

#while [ "$1" ]; do
while [ "$1" != "${1##[-+]}" ]; do
  case $1 in
    '')    echo ${errmsg}
           return 1;;
    -vmname)
           vmname=$2
           shift 2
           ;;
    -vmpath)
           vmpath=$2
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

#[[ $path =~ $st ]] || exit 1


# The name of the VM to start
#machine="Win7-raw"
machine="${vmname}"
#diskimg="Win7-raw.raw"
diskimg="$(basename ${vmpath})"
# The name of the network assigned to the VM
network="default"
# Your username, set if your path below requires it
username="blachmac"
# The folder in which the VM image resides
#dirname="/run/media/${username}/Windows"
#dirname="/run/media/${username}/DATA"
#dirname="/opt/vm"
dirname="$(dirname ${vmpath})"
cnt=0

# UNBIND KONTROLERA USB2 (INACZEJ HOST SIE WIESZA)
if [ ! "$(ps -ef |grep [q]emu)" ]
then
	# Reset the USB controller driver if required
	if [[ "${rescon}" && "${rescon}" -eq 1 ]]
	then
		sudo modprobe -r vfio_pci 2>/dev/null
		sudo modprobe -r vfio_iommu_type1 2>/dev/null
		sudo modprobe vfio_pci
		echo "0000:00:1a.0" |sudo tee /sys/bus/pci/drivers/ehci-pci/unbind 2>/dev/null
		echo 8086 1e2d |sudo tee /sys/bus/pci/drivers/vfio-pci/new_id
	fi
	## Proceed with further steps of launching the VM
	# Recreate the VM network config file with the current default gw
	sudo rm -f /tmp/${network}.xml
	sudo virsh net-dumpxml --inactive ${network} > /tmp/${network}.xml
	sudo virsh net-destroy ${network}

	# Determine the local default router IP (I assume here it's going to be the main DNS for the vm)
	dns="$(ip ro|grep "default.* "|sed 's/default via //;s/ .*//')"

	# Spit out an error if the address cannot be found
	[ ! "${dns}" ] && ( logger "No DNS/default router IP found. Check your network configuration."; exit 1 )

	sudo sed -i'' "s/forwarder addr=.*/forwarder addr='${dns}'\/>/" /tmp/${network}.xml
	sudo virsh net-define /tmp/${network}.xml
	sudo virsh net-start ${network}
	sudo rm -f /tmp/${network}.xml
fi
# Wait up to 30s for the default router and the path specified above to appear
until [[ "${cnt}" -eq 30 || ( -n "$(ip ro|grep default)" && -d "${dirname}" ) ]]
do
	let cnt++
	sleep 1
done
#echo test1
# Check if you finally have a default router (you usually need one when working on the net :) )
[ -z "$(ip ro|grep default)" ] && ( logger "Default router not found. Check your network configuration"; exit 1 )
#echo test2

# Determine if the folder name set in the variable above is correct
[ ! -d "${dirname}" ] && ( logger "${machine} image cannot be located. Check for the existence of ${dirname}"; exit 1 )

# Build a folder tree and change its permissions accordingly (a hack really, but it's simpler this way)
paths=($(for dir in $(echo ${dirname}|sed 's/\// /g');do path="${path}/${dir}";echo -n "${path} ";done))
for dir in $(echo ${paths[@]:1})
do
	sudo setfacl -m u:qemu:rwx ${dir}
done
sudo setfacl -m u:qemu:rwx ${dirname}
sudo setfacl -R -m u:qemu:rwx ${dirname}/${diskimg}
sudo sed -i'' "s+<source file='.*'/>+<source file='${vmpath}'/>+" /etc/libvirt/qemu/${vmname}.xml
sudo service libvirtd restart

[ -n "${username}" ] && sudo setfacl -R -m u:${username}:rwx ${dirname}/${diskimg}
sudo virsh start ${machine}

