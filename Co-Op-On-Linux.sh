#!/bin/bash

SOURCE=${BASH_SOURCE[0]}
CONFIG_APPROACH="${CONFIG_APPROACH:-}"  # Can be: copy, args, or home
GAMERUN_BASE="${GAMERUN:-}"
GAMERUN_EXTRA_ARGS="${GAMERUN_EXTRA_ARGS:-}" # Additional arguments for non-host/player 1 players
export STEAM_CLOUD_SYNC=0

create_player_config() {
    local i=$1
    local width=$2
    local height=$3

    echo "default_border none 0" > "$DIR_CO_OP_SWAY/sway$i.conf"
    echo "output WL-1 resolution ${width}x${height}" >> "$DIR_CO_OP_SWAY/sway$i.conf"
    echo "output X11-1 resolution ${width}x${height}" >> "$DIR_CO_OP_SWAY/sway$i.conf"

    if [ "$i" -eq 0 ]; then
        # First player (host) uses default config
        exec_command="WAYLAND_DISPLAY=wayland-$i firejail --noprofile ${controller_firejail_args[$i]} ${GAMERUN_BASE}"
    else
        # Handle different configuration approaches for non-host players
        case "$CONFIG_APPROACH" in
            "copy")
                if [ -n "$GAME_CONFIG_PARAM" ] && [ -n "$GAME_CONFIG_GUEST" ]; then
                    exec_command="WAYLAND_DISPLAY=wayland-$i firejail --noprofile ${controller_firejail_args[$i]} ${GAMERUN_BASE} ${GAMERUN_EXTRA_ARGS} $GAME_CONFIG_PARAM $GAME_CONFIG_GUEST"
                fi
                ;;
            "args")
                exec_command="WAYLAND_DISPLAY=wayland-$i firejail --noprofile ${controller_firejail_args[$i]} ${GAMERUN_BASE} ${GAMERUN_EXTRA_ARGS}"
                ;;
            "home")
                if [ -n "$GAME_HOME_DIR" ]; then
                    exec_command="WAYLAND_DISPLAY=wayland-$i HOME=${GAME_HOME_DIR} firejail --noprofile ${controller_firejail_args[$i]} ${GAMERUN_BASE} ${GAMERUN_EXTRA_ARGS}"
                fi
                ;;
            *)
                echo "Error: Invalid or missing CONFIG_APPROACH, default to doing nothing"
                ;;
        esac
    fi
    echo "exec $exec_command" >> "$DIR_CO_OP_SWAY/sway$i.conf"
}

# Function to launch sway sessions
launch_sway_sessions() {
    local config_type=$1
    cd $(dirname $GAMERUN_BASE)
    echo $PWD

    if [ "$config_type" = "root" ]; then
        sway -c $DIR_CO_OP_SWAY/sway_root.conf &
    else
        for i in $(seq 0 $(($CONTROLLERS_NUM - 1))); do
            sway -c $DIR_CO_OP_SWAY/sway$i.conf &
        done
    fi
}

create_guest_config() {
    if [ -n "$GAME_CONFIG_SOURCE" ] && [ -n "$GAME_CONFIG_GUEST" ] && [ -n "$GAME_CONFIG_MODIFY_CMD" ]; then
        if [ -f "$GAME_CONFIG_SOURCE" ]; then
            echo "Creating guest config from $GAME_CONFIG_SOURCE"
            cp "$GAME_CONFIG_SOURCE" "$GAME_CONFIG_GUEST"
            echo "Modifying guest config"
            eval "$GAME_CONFIG_MODIFY_CMD $GAME_CONFIG_GUEST"
            echo "Successfully created guest config at $GAME_CONFIG_GUEST"
        else
            echo "Warning: Host config file not found at $GAME_CONFIG_SOURCE"
        fi
    fi
}

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

if [ "$CONTROLLERS_NUM" -gt 1 ]; then
    create_guest_config
fi

result=$(awk -vx=$CONTROLLERS_NUM -vy=$NUM_WINDOWS 'BEGIN{ print x>=y+1?1:0}')
if [ $result -eq 1 ] && [ -n "$MULTIWINDOW" ]; then
        zenity --error --text "There are more controllers connected than windows defined in profile.
Create a profile with more windows or connect less controllers"
        exit
fi

mkdir -p $DIR_CO_OP_SWAY
rm "$DIR_CO_OP_SWAY"/*.conf

# Separate windows
if [ -n "$MULTIWINDOW" ]; then
    # Create sway config for each instance
    for i in $(seq 0 $((CONTROLLERS_NUM - 1))); do
        create_player_config $i $(eval echo \$WIDTH$((i+1))) $(eval echo \$HEIGHT$((i+1)))
    done

    launch_sway_sessions "individual"

elif [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
    # Calculate dimensions for splitscreen
    child_width=$(($WIDTH/2))
    child_height=$HEIGHT
    if [ $CONTROLLERS_NUM -ge 3 ]; then
        child_height=$(($HEIGHT/2))
    fi

    # Initialize spawn script
    mkdir -p /tmp/coop-linux
    SPAWN_SCRIPT=/tmp/coop-linux/spawn_instances.sh
    rm $SPAWN_SCRIPT; touch $SPAWN_SCRIPT
    echo "#!/usr/bin/env bash" >> $SPAWN_SCRIPT
    chmod u+x $SPAWN_SCRIPT

    # Create root sway config
    echo "default_border none 0" > $DIR_CO_OP_SWAY/sway_root.conf
    echo "output WL-1 resolution $(($WIDTH))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway_root.conf
    echo "output X11-1 resolution $(($WIDTH))x$HEIGHT" >> $DIR_CO_OP_SWAY/sway_root.conf
    echo "exec $SPAWN_SCRIPT" >> $DIR_CO_OP_SWAY/sway_root.conf

    # Create configs for each player
    for i in $(seq 0 $CONTROLLERS_NUM); do
        create_player_config $i $child_width $child_height
    done

    # Generate spawn script content
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

    launch_sway_sessions "root"
fi

echo "Done~!"
