#!/usr/bin/env sh

DIALOG=zenity
DIR_CO_OP=$PWD

if type "kdialog" > /dev/null; then
    GAMERUN=$(kdialog --title="Select game executable/launch script" --getopenfilename)
else
    GAMERUN=$(zenity --title="Select game executable/launch script" --file-selection)
fi

NUM_WINDOWS=$($DIALOG --list --title="Number of Windows" --text="Select number of windows" --radiolist --column="Choose" --column="Option" TRUE "1 window" FALSE "2 windows")

if [ "$NUM_WINDOWS" = "1 window" ]; then
    DEFAULT_RES=$(xdpyinfo | awk '/dimensions/{print $2}')
    RESOLUTION=$($DIALOG --title="Resolution" --entry --text="Enter Resolution for Weston session (for example: 1280x720)" --entry-text=$DEFAULT_RES)

    WIDTH=$(printf $RESOLUTION | awk -F "x" '{print $1}')
    HEIGHT=$(printf $RESOLUTION | awk -F "x" '{print $2}')

    name=$($DIALOG --title="Profile name" --entry --text="Enter a name for the profile" --entry-text="name")
    mkdir -p $DIR_CO_OP/profiles
    echo "export WIDTH=$WIDTH" > "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT=$HEIGHT" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export GAMERUN='$GAMERUN'" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "exec ../Co-Op-On-Linux.sh" >> "$DIR_CO_OP/profiles/$name.sh"
    chmod +x "$DIR_CO_OP/profiles/$name.sh"
else
    DEFAULT_RES=$(xdpyinfo | awk '/dimensions/{print $2}')
    RESOLUTION1=$($DIALOG --title="Resolution for Player 1" --entry --text="Enter Resolution for Weston session for Player 1 (e.g., 1280x720)" --entry-text=$DEFAULT_RES)
    RESOLUTION2=$($DIALOG --title="Resolution for Player 2" --entry --text="Enter Resolution for Weston session for Player 2 (e.g., 1280x720)" --entry-text=$DEFAULT_RES)

    WIDTH1=$(printf $RESOLUTION1 | awk -F "x" '{print $1}')
    HEIGHT1=$(printf $RESOLUTION1 | awk -F "x" '{print $2}')
    WIDTH2=$(printf $RESOLUTION2 | awk -F "x" '{print $1}')
    HEIGHT2=$(printf $RESOLUTION2 | awk -F "x" '{print $2}')

    name=$($DIALOG --title="Profile name" --entry --text="Enter a name for the profile" --entry-text="name")
    mkdir -p $DIR_CO_OP/profiles
    echo "export WIDTH1=$WIDTH1" > "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT1=$HEIGHT1" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export WIDTH2=$WIDTH2" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT2=$HEIGHT2" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export GAMERUN='$GAMERUN'" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "exec ../Co-Op-On-Linux.sh" >> "$DIR_CO_OP/profiles/$name.sh"
    chmod +x "$DIR_CO_OP/profiles/$name.sh"
fi

zenity --info --text "Preset created! To load it go to the preset folder and execute its script"
