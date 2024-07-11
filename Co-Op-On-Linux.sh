#!/bin/bash

SOURCE=${BASH_SOURCE[0]}

# https://stackoverflow.com/a/246128
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR_CO_OP=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR_CO_OP=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )

cd $DIR_CO_OP

DIR_CO_OP_CONT=$DIR_CO_OP/controller_blacklists
DIR_CO_OP_SWAY=$DIR_CO_OP/sway_configs

if [ -e steamos-check ]; then
    if ! type "sway" > /dev/null; then
        $DIR_CO_OP/install-steamos.sh
    fi
fi

if [ "$1" = --help ]; then
    echo "
    Co-Op-On-Linux.sh

    Enviroment variables:

    WIDTH: width of total area in pixels
    HEIGHT: height of total area in pixels
    GAMERUN: command to run to start the game
    "
fi


DIALOG="zenity"

### Manage game controllers
if [ "$DIR_CO_OP_CONT" != "/*" ]; then
rm -rf "$DIR_CO_OP_CONT"
else
    echo "There was a bug were accidentally your system could have been wiped. Please report it"
fi

mkdir $DIR_CO_OP_CONT


function legacy_select_controllers() {
    readarray -t CONTROLLERS < <( $DIR_CO_OP/get-devices.py list-zenity )

    zenity_out=$($DIALOG --list --title="Choose controller for player 1" --text="" --column=Controllers --column=devices \ "${CONTROLLERS[@]}" --print-column 2 )

    if [ $? -eq 1 ]; then
        echo "Canceled"
        exit
    fi

    CONTROLLER_1=$(echo $zenity_out | uniq)

    readarray -t CONTROLLERS < <( $DIR_CO_OP/get-devices.py list-zenity-exclude $CONTROLLER_1 )

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
        printf -- '--blacklist=%s ' $dev >> $DIR_CO_OP_CONT/Player1_Controller_Blacklist
    done

    # add each device to blacklist
    for dev in $CONTROLLER_2
    do
        printf -- '--blacklist=%s ' $dev >> $DIR_CO_OP_CONT/Player2_Controller_Blacklist
    done

    readarray -t CONTROLLERS_REST < <($DIR_CO_OP/get-devices.py list-handlers-exclude $CONTROLLER_1 $CONTROLLER_2)
    echo $CONTROLLERS_REST

    touch $DIR_CO_OP_CONT/Global_Controller_Blacklist
    for dev in $CONTROLLERS_REST
    do
        printf -- '--blacklist=%s ' $dev >> $DIR_CO_OP_CONT/Global_Controller_Blacklist
    done
};

function select_controllers() {
    $DIR_CO_OP/controller-selector -w $WIDTH -h $HEIGHT
    source $DIR_CO_OP/controllers.rc
    load_controller_firejail_args_array
}

if [ -z $WIDTH ] || [ -z $HEIGHT ] || [ -z $GAMERUN ]; then
    zenity --error --text "Enviroment variables not set (Did you run this without a preset?)"
    exit
fi

select_controllers

echo "(I) controller_firejail_args:"
echo ${controller_firejail_args[*]}

mkdir $DIR_CO_OP_SWAY
rm "$DIR_CO_OP_SWAY"/*.conf

# Set width and height for game instances
child_width=0
child_height=0
if [ $CONTROLLERS_NUM -lt 3 ]; then
    child_width=$(($WIDTH/2))
    child_height=$HEIGHT
else
    child_width=$(($WIDTH/2))
    child_height=$(($HEIGHT/2))
fi

# Initialize script that spawns the game instances
mkdir -p /tmp/coop-linux
SPAWN_SCRIPT=/tmp/coop-linux/spawn_instances.sh
rm $SPAWN_SCRIPT; touch $SPAWN_SCRIPT
echo "#!/usr/bin/env bash" >> $SPAWN_SCRIPT
chmod u+x $SPAWN_SCRIPT

# Create root sway config
echo "default_border none 0" > $DIR_CO_OP_SWAY/sway_root.conf
echo "output WL-1 resolution $(($WIDTH))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway_root.conf
# Set resolution for X11 and Xwayland compositors (eg. gamescope)
echo "output X11-1 resolution $(($WIDTH))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway_root.conf
echo "exec $SPAWN_SCRIPT" >> $DIR_CO_OP_SWAY/sway_root.conf

# Create sway config for instance containers
for i in $(seq 0 $CONTROLLERS_NUM); do
    echo "default_border none 0" > $DIR_CO_OP_SWAY/sway$i.conf
    echo "output WL-1 resolution ${child_width}x${child_height}" >> $DIR_CO_OP_SWAY/sway$i.conf
    exec_command="WAYLAND_DISPLAY=wayland-$i firejail --noprofile ${controller_firejail_args[$i]} $GAMERUN"
    echo "exec $exec_command" >> $DIR_CO_OP_SWAY/sway$i.conf
done

if [ $CONTROLLERS_NUM -gt 2 ]; then
    echo "swaymsg splith" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg exec \"sway -c $DIR_CO_OP_SWAY/sway0.conf\"" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg exec \"sway -c $DIR_CO_OP_SWAY/sway1.conf\"" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg focus left" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg splitv" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg exec \"sway -c $DIR_CO_OP_SWAY/sway2.conf\"" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg focus left" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    echo "swaymsg splitv" >> $SPAWN_SCRIPT
    echo "sleep 1" >> $SPAWN_SCRIPT
    if [ $CONTROLLERS_NUM -eq 3 ]; then
        echo "swaymsg exec glxgears" >> $SPAWN_SCRIPT
    else
        echo "swaymsg exec \"sway -c $DIR_CO_OP_SWAY/sway3.conf\"" >> $SPAWN_SCRIPT
    fi
else
    for i in $(seq 0 $(($CONTROLLERS_NUM - 1))); do
        echo "swaymsg exec \"sway -c $DIR_CO_OP_SWAY/sway$i.conf\"" >> $SPAWN_SCRIPT
    done
fi

### Launching sway sessions
cd $(dirname $GAMERUN)
echo $PWD
sway -c $DIR_CO_OP_SWAY/sway_root.conf &

echo "Done~!"
