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
    RESOLUTION1=$($DIALOG --title="Resolution" --entry --text="Enter screen resolution for player 1 ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
    WIDTH1=$(printf $RESOLUTION1 | awk -F "x" '{print $1}')
    HEIGHT1=$(printf $RESOLUTION1 | awk -F "x" '{print $2}')
    RESOLUTION2=$($DIALOG --title="Resolution" --entry --text="Enter screen resolution for player 2 ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
    WIDTH2=$(printf $RESOLUTION2 | awk -F "x" '{print $1}')
    HEIGHT2=$(printf $RESOLUTION2 | awk -F "x" '{print $2}')
    RESOLUTION3=$($DIALOG --title="Resolution" --entry --text="(If Applicable) Enter screen resolution for player 3 ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
    WIDTH3=$(printf $RESOLUTION3 | awk -F "x" '{print $1}')
    HEIGHT3=$(printf $RESOLUTION3 | awk -F "x" '{print $2}')
    RESOLUTION4=$($DIALOG --title="Resolution" --entry --text="(If Applicable) Enter screen resolution for player 4 ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
    WIDTH4=$(printf $RESOLUTION4 | awk -F "x" '{print $1}')
    HEIGHT4=$(printf $RESOLUTION4 | awk -F "x" '{print $2}')
elif [ "$MULTIWINDOW" = "Splitscreen Window" ]; then
    RESOLUTION=$($DIALOG --title="Resolution" --entry --text="Enter screen resolution ( for example: 1280x720 ) " --entry-text=$DEFAULT_RES)
    WIDTH=$(printf $RESOLUTION | awk -F "x" '{print $1}')
    HEIGHT=$(printf $RESOLUTION | awk -F "x" '{print $2}')
fi

name=$($DIALOG --title="Profile name" --entry --text="Enter a name for the profile" --entry-text="name")
mkdir -p "$DIR_CO_OP"/profiles
echo "#!/bin/bash" > "$DIR_CO_OP/profiles/$name.sh"

if [ "$MULTIWINDOW" = "Separate Windows" ]; then
    echo "export WIDTH1=$WIDTH1" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT1=$HEIGHT1" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export WIDTH2=$WIDTH2" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT2=$HEIGHT2" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export WIDTH3=$WIDTH3" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT3=$HEIGHT3" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export WIDTH4=$WIDTH4" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT4=$HEIGHT4" >> "$DIR_CO_OP/profiles/$name.sh"
elif [ "$MULTIWINDOW" = "Splitscreen Window" ]; then
    echo "export WIDTH=$WIDTH" >> "$DIR_CO_OP/profiles/$name.sh"
    echo "export HEIGHT=$HEIGHT" >> "$DIR_CO_OP/profiles/$name.sh"
fi

echo "export GAMERUN='$GAMERUN'" >> "$DIR_CO_OP/profiles/$name.sh"
echo "../Co-Op-On-Linux.sh" >> "$DIR_CO_OP/profiles/$name.sh"
chmod +x "$DIR_CO_OP/profiles/$name.sh"

zenity --info --text "Preset created! To load it go to the preset folder and execute its script"
