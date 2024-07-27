#!/usr/bin/env sh
#
DIALOG=zenity
DIR_CO_OP=$PWD

if type "kdialog" > /dev/null; then
    GAMERUN=$(kdialog --title="Select game executable/launch script" --getopenfilename)
else
    GAMERUN=$(zenity --title="Select game executable/launch script" --file-selection)
fi

DEFAULT_RES=$(xdpyinfo | awk '/dimensions/{print $2}')

MULTIWINDOW=$($DIALOG --title="Separate Windows Per Player?" --list --radiolist --column "Pick" --column "Option" TRUE "Splitscreen Window" FALSE "Separate Windows")

if [ "$MULTIWINDOW" = "Separate Windows" ]; then
    NUM_WINDOWS=$($DIALOG --title="Number of windows" --entry --text="Enter the total number of windows (for example: 2)" --entry-text=2)
    declare -a MW_WIDTHS
    declare -a MW_HEIGHTS
    for i in $(seq 0 $((NUM_WINDOWS - 1))); do
      RESOLUTION=$($DIALOG --title="Resolution" --entry --text="Enter screen resolution for player 1 ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
      MW_WIDTHS+=$(printf $RESOLUTION | awk -F "x" '{print $1}')
      MW_HEIGHTS+=$(printf $RESOLUTION | awk -F "x" '{print $2}')
    done
elif [ "$MULTIWINDOW" = "Splitscreen Window" ]; then
    RESOLUTION=$($DIALOG --title="Resolution" --entry --text="Enter screen resolution ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
    WIDTH=$(printf $RESOLUTION | awk -F "x" '{print $1}')
    HEIGHT=$(printf $RESOLUTION | awk -F "x" '{print $2}')
fi

name=$($DIALOG --title="Profile name" --entry --text="Enter a name for the profile" --entry-text="name")
mkdir -p "$DIR_CO_OP"/profiles
echo "#!/bin/bash" > "$DIR_CO_OP/profiles/$name.sh"

if [ "$MULTIWINDOW" = "Separate Windows" ]; then
    echo "export MULTIWINDOW=1" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export NUM_WINDOWS=$NUM_WINDOWS" >> "$DIR_CO_OP/profiles/$name.sh"
    for i in $(seq 0 $((NUM_WINDOWS - 1))); do
      echo "export WIDTH$(($i + 1))=${MW_WIDTHS[$i]}" >> "$DIR_CO_OP/profiles/$name.sh"
      echo "export HEIGHT$(($i + 1))=${MW_HEIGHTS[$i]}" >> "$DIR_CO_OP/profiles/$name.sh"
    done
elif [ "$MULTIWINDOW" = "Splitscreen Window" ]; then
    echo "export WIDTH=$WIDTH" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT=$HEIGHT" >> "$DIR_CO_OP/profiles/$name.sh"
fi

echo "export GAMERUN='$GAMERUN'" >> "$DIR_CO_OP/profiles/$name.sh"
echo "../Co-Op-On-Linux.sh" >> "$DIR_CO_OP/profiles/$name.sh"
chmod +x "$DIR_CO_OP/profiles/$name.sh"

zenity --info --text "Preset created! To load it go to the preset folder and execute its script"
