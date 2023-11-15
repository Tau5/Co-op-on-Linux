#!/bin/bash

DIR_CO_OP=$PWD
DIR_CO_OP_WEST=$DIR_CO_OP/weston_configs
DIR_CO_OP_CONT=$DIR_CO_OP/controller_blacklists
DIR_CO_OP_SWAY=$DIR_CO_OP/sway_configs


### Currently only 2 players is supported 

if [ "$1" = --help ]; then
echo "
====C-O-O-L======================================================================X========
||											||
||	--- how to use quickrun ---							||
||											||
||	~ ./Co-Op-On-linux.sh --quickrun resolution /path/to/the/game			||
||											||
||	--- Example ---									||
||											||
||	~ ./Co-Op-On-linux.sh --quickrun 1280x720 /home/user/path/to/thegame		||
||											||
||											||
||--------------------------------------------------------------------------------------||
||   ! note ! : You need to run the script without --quickrun to regenerate configs.	||
||--------------------------------------------------------------------------------------||
||											||
==========================================================================================
"
else


### Checking for --quickrun

if [ "$1" = --quickrun ] ; then
echo "Quickrun is used, The Controller and Resolution setup will be skipped for now
Run the script again without --quickrun or delete controller_blacklists folder if you want to reconfigure the controllers"
else
echo "Quickrun is not used, type --help for more information"
fi


### Manage game controllers 
if [ "$1" = --quickrun ] && [ -d $DIR_CO_OP_CONT ] ; then
echo "Controllers already Configured."
else
rm -rf $DIR_CO_OP_CONT
mkdir $DIR_CO_OP_CONT
readarray -t CONTROLLERS < <( python get-devices.py )

CONTROLLER_1=$(zenity --list --title="Choose controller for player 1" --text="" --column=Controllers --column=devices \ "${CONTROLLERS[@]}" --print-column 2 | uniq)
CONTROLLER_2=$(zenity --list --title="Choose controller for player 2" --text="" --column=Controllers --column=devices \ "${CONTROLLERS[@]}" --print-column 2 | uniq)

# add each device to blacklist
for dev in $CONTROLLER_1
do
    printf -- '--blacklist=/dev/input/%s ' $dev >> $DIR_CO_OP_CONT/Player1_Controller_Blacklist
done

# add each device to blacklist
for dev in $CONTROLLER_2
do
    printf -- '--blacklist=/dev/input/%s ' $dev >> $DIR_CO_OP_CONT/Player2_Controller_Blacklist
done

fi


### Getting game path/command

if [ "$1" = --quickrun ]; then
GAMERUN="${@:3}"
else 
GAMERUN=$(zenity --title="Select game executable/launch script" --file-selection)
fi


### Writing Config files for Weston

if [ -d $DIR_CO_OP_WEST ]; then
echo "Weston Configurations already exist."
else
mkdir $DIR_CO_OP_WEST
printf "[core]
xwayland=true
idle-time=0
shell=kiosk
[shell]
locking=false
[keyboard]
keymap_layout=gb
" >> $DIR_CO_OP_WEST/weston0.ini
cp $DIR_CO_OP_WEST/weston0.ini $DIR_CO_OP_WEST/weston1.ini
cp $DIR_CO_OP_WEST/weston0.ini $DIR_CO_OP_WEST/weston2.ini
fi

### Setup resolution for Weston sessions

if [ "$1" = --quickrun ]; then
RESOLUTION=($2)
else
RESOLUTION=$(zenity --title="Resolution" --entry --text="Enter Resolution for Weston sessions ( for example: 1280x720 ) " --entry-text="1280x720")
fi

WIDTH=$(printf $RESOLUTION | awk -F "x" '{print $1}')
HEIGHT=$(printf $RESOLUTION | awk -F "x" '{print $2}')

exec_command1="WAYLAND_DISPLAY=wayland-2 firejail --noprofile $(cat $DIR_CO_OP_CONT/Player2_Controller_Blacklist ) $GAMERUN"
exec_command2="WAYLAND_DISPLAY=wayland-2 firejail --noprofile $(cat $DIR_CO_OP_CONT/Player1_Controller_Blacklist ) $GAMERUN"

mkdir $DIR_CO_OP_SWAY
rm $DIR_CO_OP_SWAY/*.conf

echo "default_border none 0" > $DIR_CO_OP_SWAY/sway0.conf
echo "output WL-1 resolution $(($WIDTH*2))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway0.conf
echo "exec sway -c $DIR_CO_OP_SWAY/sway1.conf" >> $DIR_CO_OP_SWAY/sway0.conf
echo "exec sway -c $DIR_CO_OP_SWAY/sway2.conf" >> $DIR_CO_OP_SWAY/sway0.conf

echo "default_border none 0" > $DIR_CO_OP_SWAY/sway1.conf
echo "output WL-1 resolution $(($WIDTH))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway1.conf
echo "exec $exec_command1" >> $DIR_CO_OP_SWAY/sway1.conf

echo "default_border none 0" > $DIR_CO_OP_SWAY/sway2.conf
echo "output WL-1 resolution $(($WIDTH))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway2.conf
echo "exec $exec_command2" >> $DIR_CO_OP_SWAY/sway2.conf

### Launching Weston sessions
#weston --xwayland -c "$DIR_CO_OP_WEST/weston1.ini" --width=$WIDTH --height=$HEIGHT 2> /dev/null &
#weston --xwayland -c "$DIR_CO_OP_WEST/weston2.ini" --width=$WIDTH --height=$HEIGHT 2> /dev/null &

### Launching sway sessions

sway -c $DIR_CO_OP_SWAY/sway0.conf &

#WAYLAND_DISPLAY=wayland-1 sway -c $DIR_CO_OP_SWAY/sway1.conf &
#WAYLAND_DISPLAY=wayland-1 sway -c $DIR_CO_OP_SWAY/sway2.conf &

#notneeded=$(ps l | grep weston0.ini | awk 'length($0) > 120 {print $3}')
#kill $notneeded
sleep 3

#---Player 1---#
#sleep 5
#DISPLAY=:3 WAYLAND_DISPLAY=wayland-2 firejail --noprofile $(cat $DIR_CO_OP_CONT/Player2_Controller_Blacklist ) "$GAMERUN" &
#sleep 1
#---Player 2---#
#DISPLAY=:4 WAYLAND_DISPLAY=wayland-3 firejail --noprofile $(cat $DIR_CO_OP_CONT/Player1_Controller_Blacklist ) "$GAMERUN" &
#sleep 1


echo "Done~!"
fi
