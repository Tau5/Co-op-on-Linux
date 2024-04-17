#!/bin/bash

DIR_CO_OP=$PWD
DIR_CO_OP_CONT=$DIR_CO_OP/controller_blacklists
DIR_CO_OP_SWAY=$DIR_CO_OP/sway_configs


### Currently only 2 players is supported

if [ -e steamos-check ]; then
    if ! type "sway" > /dev/null; then
        ./install-steamos.sh
    fi
fi

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

DIALOG="zenity"

### Manage game controllers 
if [ "$1" = --quickrun ] && [ -d $DIR_CO_OP_CONT ] ; then
echo "Controllers already Configured."
else
    if [ "$DIR_CO_OP_CONT" != "/*" ]; then
    rm -rf $DIR_CO_OP_CONT
    else
        echo "There was a bug were accidentally your system could have been wiped. Please report it"
    fi

    mkdir $DIR_CO_OP_CONT


    readarray -t CONTROLLERS < <( ./get-devices.py list-zenity )

    zenity_out=$($DIALOG --list --title="Choose controller for player 1" --text="" --column=Controllers --column=devices \ "${CONTROLLERS[@]}" --print-column 2 )

    if [ $? -eq 1 ]; then
        echo "Canceled"
        exit
    fi

    CONTROLLER_1=$(echo $zenity_out | uniq)

    readarray -t CONTROLLERS < <( ./get-devices.py list-zenity-exclude $CONTROLLER_1 )

    zenity_out=$($DIALOG --list --title="Choose controller for player 2" --text="" --column=Controllers --column=devices \ "${CONTROLLERS[@]}" --print-column 2 )

    if [ $? -eq 1 ]; then
        echo "Canceled"
        exit
    fi

    CONTROLLER_2=$(echo $zenity_out | uniq)
    #CONTROLLER_2=$($DIALOG --list --title="Choose controller for player 2" --text="" --column=Controllers --column=devices \ "${CONTROLLERS[@]}" --print-column 2 | uniq)

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

    readarray -t CONTROLLERS_REST < <(./get-devices.py list-handlers-exclude $CONTROLLER_1 $CONTROLLER_2)
    echo $CONTROLLERS_REST

    touch $DIR_CO_OP_CONT/Global_Controller_Blacklist
    for dev in $CONTROLLERS_REST
    do
        printf -- '--blacklist=/dev/input/%s ' $dev >> $DIR_CO_OP_CONT/Global_Controller_Blacklist
    done

fi


### Getting game path/command

if [ "$1" = --quickrun ]; then
    GAMERUN="${@:3}"
else
    if type "kdialog" > /dev/null; then
        GAMERUN=$(kdialog --title="Select game executable/launch script" --getopenfilename)
    else
        GAMERUN=$(zenity --title="Select game executable/launch script" --file-selection)
    fi
fi

if [ "$1" = --quickrun ]; then
RESOLUTION=($2)
else
RESOLUTION=$($DIALOG --title="Resolution" --entry --text="Enter Resolution for Weston sessions ( for example: 1280x720 ) " --entry-text="1280x720")
fi

WIDTH=$(printf $RESOLUTION | awk -F "x" '{print $1}')
HEIGHT=$(printf $RESOLUTION | awk -F "x" '{print $2}')

exec_command1="WAYLAND_DISPLAY=wayland-2 firejail --noprofile $(cat $DIR_CO_OP_CONT/Player2_Controller_Blacklist ) $(cat $DIR_CO_OP_CONT/Global_Controller_Blacklist) $GAMERUN"
exec_command2="WAYLAND_DISPLAY=wayland-2 firejail --noprofile $(cat $DIR_CO_OP_CONT/Player1_Controller_Blacklist ) $(cat $DIR_CO_OP_CONT/Global_Controller_Blacklist) $GAMERUN"

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

### Launching sway sessions

sway -c $DIR_CO_OP_SWAY/sway0.conf &

echo "Done~!"
fi
