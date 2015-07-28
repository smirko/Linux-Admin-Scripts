#!/bin/bash

#######################################################################################
#
#   Script to toggle between two of the available sound sources
#	You'll need pacmd supplied by pulseaudio-utils
#
#   Created by - Maciej 'Smirk' Blachnio 2015.07
#
#	This program is under GPL [http://www.gnu.org/licenses/gpl.html]
#
#   Modify the following to match your configuration
#	Vars: card1, card2, cprof1, cprof2
#
#######################################################################################


# If you use Pulseaudio/ALSA and want to find out the names of audio devices present in your system
# issue: pacmd list-cards
# from a terminal run by the same user you logged into the X session
# and look for "alsa.card_name" attributes. Set them below accordingly as card1 and card2.
card1="HDA Intel PCH"
card2="Jabra BIZ 2400 USB"

# Do the same with target profiles for each device
# issue: pacmd list-cards
# and then look for available "profiles:". Put the desired ones below as cprof1 and cprof2
cprof1="output:analog-stereo+input:analog-stereo"
cprof2="output:iec958-stereo+input:analog-mono"

switch=""
cards=()

# Find the indexes of all the available audio devices and put them into an array
indexes=($(pacmd list-cards|sed '/index: /!d;s/.*index: //'))

# Find names of the devices and put them into an array for later processing
for index in ${indexes[*]}
do
	cards[${index}]=$(pacmd list-cards|sed '/index: '${index}'/,/active profile: /!d;/alsa.card_name = /!d;s/^.*alsa.card_name = "//g;s/"//')
done

# Toggle between the 2 cards set above
for index in ${!cards[*]}
do
	if [ "${cards[${index}]}" == "${card1}" ]
	then
		prof1="$(pacmd list-cards|sed '/index: '${index}'/,/active profile:/!d;/active profile:/!d;s/^.*active profile: <//;s/>$//')"
		[ "${prof1}" == "off" ] && pacmd set-card-profile ${index} ${cprof1} && switch="on" || pacmd set-card-profile ${index} off
	fi
	if [ "${cards[${index}]}" == "${card2}" ]
	then
		prof2="$(pacmd list-cards|sed '/index: '${index}'/,/active profile:/!d;/active profile:/!d;s/^.*active profile: <//;s/>$//')"
		[[ "${prof2}" == "off" || "${switch}" != "on" ]] && pacmd set-card-profile ${index} ${cprof2} || pacmd set-card-profile ${index} off
	fi
done
