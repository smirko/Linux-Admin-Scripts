#!/bin/bash

#######################################################################################
#
#   Script to watch for remote host availability that:
#	- restarts interfaces specified
#	- reloads their kernel modules
#	- reboots the device if none of the above helps
#
#	WARNING! You should know what you're doing, as remote WAN hosts tend 
#		 to become unavailable for reasons other than local interface issues.
#		 It's probably best to point your probes at hosts directly connected
#		 to the same infrastructure as the host you run this script on
#
#   Created by - Maciej 'Smirk' Blachnio 2015.07
#
#	This program is under GPL [http://www.gnu.org/licenses/gpl.html]
#
#   Modify the following to match your configuration
#	Arrays: tests, ints, mods, cnts
#	Vars: hf, max, reboot, history
#
#######################################################################################


[ "$(whoami)" != "root" ] && echo "ERROR! You must be root or a sudoer to run this script! Exiting..." && exit 1

[[ "$(which ifup &>/dev/null;echo $?)" -ne 0 || "$(which ifdown &>/dev/null;echo $?)" -ne 0 ]] && echo "ERROR! You need to have ifup/ifdown in your PATH! Exiting..." && exit 1

on() {
	## BELOW SOME EXAMPLE VALUES, CHANGE TO YOUR NEEDS
	# Array list of remote servers to check (index) and local IPs to ping them with (value)
	declare -A tests
	tests=( ["10.0.0.1"]="10.0.0.21" ["192.168.4.1"]="192.168.4.2" )
	
	# Array list of local addresses (index) and interface names (value)
	declare -A ints
	ints=( ["10.0.0.21"]="eth1" ["192.168.4.2"]="wlan1" )
	intcnt=0

	# Array list of modules (index) and interfaces that use them (value)
	# WARNING! Some interfaces might share the same modules.
	# Reloading kernel modules shared between interfaces will cause all of of them to temporarily lose connectivity
	declare -A mods
	mods=( ["e1000"]="eth1" ["tg3"]="wlan1" )
	
	# Array list of counters with index being the interface name
	declare -A cnts
	cnts=( ["eth1"]=0 ["wlan1"]=0 )
	
	# Maximum retries required to reload modules and reboot the device
	max=5
	reboot=10

	# Make sure the history file exists
	hf="/opt/keepalive.log"
	touch ${hf}
	
	# Maximum backwards history to store inside the above log
	history=100
	
	# Check to see if history file exists
	[ ! -e ${hf} ] && echo "The history file \"${hf}\" couldn't be found. Exiting..." && exit 1
	
	while true
	do
		# Check to see if we hit the history cap, clear the log if so
		[ "$(grep -c ^ ${hf})" -ge ${history} ] && > ${hf}
	
		# Iterate through remote IPs
		for ip in ${!tests[@]}
		do
			# Iterate through local IPs
			for i in ${!ints[@]}
			do
				# If we have a match between local IP and its interface, start testing
				if [ ${tests[$ip]} == "${i}" ]
				then
					ping -c3 ${ip} &>/dev/null
					res=$?
					if [ ${res} -ne 0 ]
					then
						# Toggle the interface if ping is unsuccessful
						ifdown ${ints[$i]}
						sleep 2
						ifup ${ints[$i]}
						echo "$(date +"%F %T") - ${ints[$i]} - interface restart" >> ${hf}
						
						# Check again, maybe the toggle helped
						ping -c3 ${ip} &>/dev/null
						res=$?
						
						# No? Oh, well... Increase the counter then
						if [ ${res} -ne 0 ]
						then
							let cnts[${ints[$i]}]++
						fi
												
						# Check the counter to see if we hit the interface restart maximum
						if [ ${cnts[${ints[$i]}]} -eq ${max} ] 
						then
							ifdown ${ints[$i]}
							sleep 2
	
							# Iterate through modules, look for the ones used by our interface and reload them
							for s in "${!mods[@]}"
							do
								if [ "${mods[$s]}" == ${ints[$i]} ]
								then
									modprobe -r $s
									sleep 2
									modprobe $s
									sleep 2
								fi
							done
							ifup ${ints[$i]}
							echo "$(date +"%F %T") - ${cnts[${ints[$i]}]}=${max} - reloaded modules and restarted interface ${ints[$i]}" >> ${hf}
						fi
						
						# Check the counter to see if we hit the module reload maximum
						if [ ${cnts[${ints[$i]}]} -eq ${reboot} ] 
						then
							echo "$(date +"%F %T") - ${cnts[${ints[$i]}]}=${reboot} - ${ints[$i]} unuseable - commencing device reboot" >> ${hf}
							cnts[${ints[$i]}]=0
							reboot
						fi
					else
						cnts[${ints[$i]}]=0
						let intcnt++
						[ "${intcnt}" -eq "${#ints[*]}" ] && sleep 120
					fi				
				fi
			done
		done
		sleep 0.5
		intcnt=0
	done &
}

off() {
	killall	$(basename $(echo $0))
}

check() {
	[ -n "$(ps -ef |grep $0|grep -v "grep\|status")" ] && echo "$0 is running..." && exit 0 || echo "$0 is not running..." && exit 1
}

case $1 in
'start')
	on
        ;;

'stop')
	off
        ;;
'status')
	check
        ;;


*)
        echo "usage: $0 {start|stop|status}"
        ;;
esac
