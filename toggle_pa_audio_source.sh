#!/bin/bash

#######################################################################################
#
#   Script to toggle between two of the available sound sources
#      You'll need pacmd supplied by pulseaudio-utils
#
#   Created by - Maciej 'Smirk' Blachnio 2015.07
#
#      This program is under GPL [http://www.gnu.org/licenses/gpl.html]
#
#   Modify the following to match your configuration
#      Vars: card1, card2, cprof1, cprof2
#
#######################################################################################


# If you use Pulseaudio/ALSA and want to find out the names of Audio Devices present in your system
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
indexes=($(pacmd list-cards|sed '/index: /!d;s/.*index: //'))

for ind in ${indexes[*]}
do
	cards[${ind}]=$(pacmd list-cards|sed '/index: '${ind}'/,/active profile: /!d;/alsa.card_name = /!d;s/^.*alsa.card_name = "//g;s/"//')
done

for ind in ${!cards[*]}
do
	prof="$(pacmd list-cards|sed '/index: '${ind}'/,/active profile:/!d;/active profile:/!d;s/^.*active profile: <//;s/>$//')"
	if [ "${cards[${ind}]}" == "${card1}" ]
	then
		if [ "${prof}" == "off" ]
		then
			pacmd set-card-profile ${ind} ${cprof1}
		else
			pacmd set-card-profile ${ind} off; echo "${card1} set to off"
		fi
	else
                if [ "${prof}" == "off" ]
                then
                        pacmd set-card-profile ${ind} ${cprof2}
                else
                        pacmd set-card-profile ${ind} off; echo "${card2} set to off"
                fi
	fi
done
