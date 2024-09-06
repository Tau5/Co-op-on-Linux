#!/bin/bash

SOURCE=${BASH_SOURCE[0]}

# https://stackoverflow.com/a/246128
while [ -L "$SOURCE" ]; do
  DIR_CO_OP=$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE
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

    Enviroment variables for splitscreen window:

    WIDTH: width of total area in pixels
    HEIGHT: height of total area in pixels
    GAMERUN: command to run to start the game

    Environmental variables for separate windows:
    WIDTH1: width of first window
    HEIGHT1: height of first window
    WIDTH2: width of second window
    HEIGHT2: height of second window
    WIDTH3: (if applicable) width of third window
    HEIGHT3: (if applicable) height of third window
    WIDTH4: (if applicable) width of fourth window
    HEIGHT4: (if applicable) height of fourth window
    GAMERUN: command to run to start the game
    "
fi

DIALOG="zenity"

### Manage game controllers
if [ "$DIR_CO_OP_CONT" != "/*" ]; then
rm -rf "$DIR_CO_OP_CONT"
else
    echo "There was a bug where accidentally your system could have been wiped. Please report it"
fi

mkdir $DIR_CO_OP_CONT

# Function to list Proton versions
function list_proton_versions() {
    local proton_dir="$HOME/.steam/steam/steamapps/common"
    local versions=()
    
    for dir in "$proton_dir"/Proton*; do
        if [ -d "$dir" ]; then
            versions+=($(basename "$dir"))
        fi
    done
    
    echo "${versions[@]}"
}

# Function to select Proton version
function select_proton_version() {
    local versions
    versions=$(list_proton_versions)
    
    if [ -z "$versions" ]; then
        zenity --error --text "No Proton versions found."
        exit 1
    fi

    local selected_version
    selected_version=$(zenity --list --title="Select Proton Version" --text="Choose the Proton version to use" --column="Proton Versions" $versions)

    if [ $? -ne 0 ]; then
        echo "Selection cancelled."
        exit 1
    fi

    echo "$selected_version"
}

# Function to run game with Proton
function run_with_proton() {
    local game_path="$1"
    local proton_version="$2"
    
    if [ -f "$game_path" ] && [[ "$game_path" == *.exe ]]; then
        local proton_dir="$HOME/.steam/steam/steamapps/common/$proton_version"
        local proton_executable="$proton_dir/proton"

        if [ ! -x "$proton_executable" ]; then
            zenity --error --text "Selected Proton version executable not found."
            exit 1
        fi

        echo "Running $game_path with Proton $proton_version..."
        "$proton_executable" run "$game_path"
    else
        echo "Running $game_path..."
        $GAMERUN
    fi
}

# Call to select Proton version
PROTON_VERSION=$(select_proton_version)

# Check and run game
run_with_proton "$GAMERUN" "$PROTON_VERSION"

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
    if [ -z "$WIDTH" ] || [ -z "$HEIGHT" ]; then
        width=$WIDTH1
        height=$HEIGHT1
    else
        width=$WIDTH
        height=$HEIGHT
    fi

    rm $DIR_CO_OP/controllers.rc
    pushd $DIR_CO_OP/controller-selector
      ./controller-selector -w $width -h $height
    popd
    if ! [ -f $DIR_CO_OP/controllers.rc ]; then
      zenity --error --text "Controller selector failed to open or failed to generate controllers file"
      exit
    fi
    source $DIR_CO_OP/controllers.rc
    load_controller_firejail_args_array
}

if ([ -z $WIDTH ] || [ -z $HEIGHT ] || [ -z "${GAMERUN}" ]) && [ -z $MULTIWINDOW ]; then
    zenity --error --text "Environment variables not set (Did you run this without a preset?)"
    exit
elif [ -n "$MULTWINDOW" ]; then
    for i in $(seq 1 $((NUM_WINDOWS))); do
      WIDTH=$(eval "printf \${WIDTH$i}")
      HEIGHT=$(eval "printf \${WIDTH$i}")
      if [ -z $WIDTH ] || [ -z $HEIGHT ]; then
        zenity --error --text "Environment variables not set (Did you run this without a preset?)"
        exit
      fi
    done
fi

select_controllers

echo "(I) controller_firejail_args:"
echo ${controller_firejail_args[*]}

result=$(awk -vx=$CONTROLLERS_NUM -vy=$NUM_WINDOWS 'BEGIN{ print x>=y+1?1:0}')
if ([ $result -eq 1 ] && [ -n "$MULTIWINDOW" ] || 1); then
        zenity --error --text "There are more controllers connected than windows defined in profile.
Create a profile with more windows or connect less controllers"
        exit
fi

mkdir $DIR_CO_OP_SWAY
rm "$DIR_CO_OP_SWAY"/*.conf

# Separate windows
if [ -n "$MULTIWINDOW" ]; then
    # Create sway config for each instance
    for i in $(seq 0 $((CONTROLLERS_NUM - 1))); do
        echo "default_border none 0" > "$DIR_CO_OP_SWAY/sway$i.conf"
        echo "output WL-1 resolution $(($(eval echo \$WIDTH$((i+1)))))x$(eval echo \$HEIGHT$((i+1)))" >> "$DIR_CO_OP_SWAY/sway$i.conf"
        echo "output X11-1 resolution $(($(eval echo \$WIDTH$((i+1)))))x$(eval echo \$HEIGHT$((i+1)))" >> "$DIR_CO_OP_SWAY/sway$i.conf"
        exec_command="WAYLAND_DISPLAY=wayland-$i firejail --noprofile ${controller_firejail_args[$i]} '${GAMERUN}'"

        "exec $exec_command" >> "$DIR_CO_OP_SWAY/sway$i.conf"
    done

    ### Launching sway sessions
    cd $(dirname $GAMERUN)
    echo $PWD
    for i in $(seq 0 $(($CONTROLLERS_NUM - 1))); do
        sway -c $DIR_CO_OP_SWAY/sway$i.conf &
    done
# Splitscreen window
elif [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
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
        exec_command="WAYLAND_DISPLAY=wayland-$i firejail --noprofile ${controller_firejail_args[$i]} '${GAMERUN}'"
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

    if file "${GAMERUN}"; then
        cd $(dirname "${GAMERUN}")
    fi

    ### Launching sway sessions
    echo $PWD
    sway -c $DIR_CO_OP_SWAY/sway_root.conf &
fi

echo "Done~!"
