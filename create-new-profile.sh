#!/usr/bin/env bash
# Improved script for setting up co-op gaming profiles

# Default dialog handler
DIALOG="zenity"
DIR_CO_OP="$PWD"

# Function to handle errors
error_exit() {
    $DIALOG --error --text="$1"
    exit 1
}

# Check for dialog programs
if command -v kdialog >/dev/null 2>&1; then
    DIALOG="kdialog"
    GAMERUN=$(kdialog --title="Select game executable/launch script" --getopenfilename) || error_exit "No file selected"
else
    command -v zenity >/dev/null 2>&1 || error_exit "Neither zenity nor kdialog found. Please install one of them."
    GAMERUN=$(zenity --title="Select game executable/launch script" --file-selection) || error_exit "No file selected"
fi

# Get default resolution safely
if command -v xdpyinfo >/dev/null 2>&1; then
    DEFAULT_RES=$(xdpyinfo | awk '/dimensions/{print $2}')
else
    DEFAULT_RES="1920x1080"  # Fallback resolution
fi

# Window mode selection
MULTIWINDOW=$($DIALOG --title="Separate Windows Per Player?" --list --radiolist \
    --column "Pick" --column "Option" \
    TRUE "Splitscreen Window" \
    FALSE "Separate Windows") || error_exit "Window mode not selected"

if [ "$MULTIWINDOW" = "Separate Windows" ]; then
    # Get number of windows
    NUM_WINDOWS=$($DIALOG --title="Number of windows" --entry \
        --text="Enter the total number of windows (for example: 2)" \
        --entry-text=2) || error_exit "Number of windows not specified"

    # Validate input is a number
    if ! [[ "$NUM_WINDOWS" =~ ^[1-9][0-9]*$ ]]; then
        error_exit "Please enter a valid number greater than 0"
    fi

    declare -a MW_WIDTHS
    declare -a MW_HEIGHTS

    # Get resolution for each window
    for i in $(seq 0 $((NUM_WINDOWS - 1))); do
        RESOLUTION=$($DIALOG --title="Resolution" \
            --text="Enter screen resolution for player $(($i + 1)) ( for example: 1280x720 )" \
            --entry --entry-text="$DEFAULT_RES") || error_exit "Resolution not specified"

        # Validate resolution format
        if ! [[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
            error_exit "Invalid resolution format for player $(($i + 1)). Use format: 1280x720"
        }

        MW_WIDTHS[$i]=$(echo "$RESOLUTION" | cut -dx -f1)
        MW_HEIGHTS[$i]=$(echo "$RESOLUTION" | cut -dx -f2)
    done
else
    # Get resolution for splitscreen
    RESOLUTION=$($DIALOG --title="Resolution" \
        --text="Enter screen resolution ( for example: 1280x720 )" \
        --entry --entry-text="$DEFAULT_RES") || error_exit "Resolution not specified"

    # Validate resolution format
    if ! [[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
        error_exit "Invalid resolution format. Use format: 1280x720"
    }

    WIDTH=$(echo "$RESOLUTION" | cut -dx -f1)
    HEIGHT=$(echo "$RESOLUTION" | cut -dx -f2)
fi

# Proton handling for .exe files
if [[ "${GAMERUN,,}" == *".exe" ]]; then
    # Look for Proton installations in common locations
    PROTON_PATHS=$(find "$HOME/.steam/steam/steamapps/common" "/usr/share/steam/steamapps/common" \
        -name 'Proton*' -type d 2>/dev/null)

    if [ -z "$PROTON_PATHS" ]; then
        error_exit "No Proton installations found"
    fi

    # Generate Proton selection list
    PROTON_LIST=""
    for path in $PROTON_PATHS; do
        version=$(basename "$path")
        PROTON_LIST+="TRUE \"$version\" "
    done

    # Select Proton version
    PROTON_VERSION=$($DIALOG --title="Select Proton Version" --list --radiolist \
        --column "Pick" --column "Proton Version" \
        $(echo -e "$PROTON_LIST") \
        --text="Select the Proton version") || error_exit "Proton version not selected"

    PROTON_PATH=$(find "$HOME/.steam/steam/steamapps/common" "/usr/share/steam/steamapps/common" \
        -name "$PROTON_VERSION" -type d 2>/dev/null | head -n1)
else
    PROTON_VERSION="None"
    PROTON_PATH=""
fi

# Get profile name
name=$($DIALOG --title="Profile name" --entry \
    --text="Enter a name for the profile" \
    --entry-text="profile") || error_exit "Profile name not specified"

# Validate profile name
if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error_exit "Invalid profile name. Use only letters, numbers, underscores, and hyphens"
fi

# Create profile directory and script
mkdir -p "$DIR_CO_OP/profiles" || error_exit "Could not create profiles directory"

# Generate profile script
cat > "$DIR_CO_OP/profiles/$name.sh" << EOF
#!/bin/bash
# Auto-generated profile script for $name

EOF

if [ "$MULTIWINDOW" = "Separate Windows" ]; then
    cat >> "$DIR_CO_OP/profiles/$name.sh" << EOF
export MULTIWINDOW=1
export NUM_WINDOWS=$NUM_WINDOWS
EOF
    for i in $(seq 0 $((NUM_WINDOWS - 1))); do
        cat >> "$DIR_CO_OP/profiles/$name.sh" << EOF
export WIDTH$(($i + 1))=${MW_WIDTHS[$i]}
export HEIGHT$(($i + 1))=${MW_HEIGHTS[$i]}
EOF
    done
else
    cat >> "$DIR_CO_OP/profiles/$name.sh" << EOF
export WIDTH=$WIDTH
export HEIGHT=$HEIGHT
EOF
fi

cat >> "$DIR_CO_OP/profiles/$name.sh" << EOF
export GAMERUN='$GAMERUN'
export PROTON_VERSION='$PROTON_VERSION'
export PROTON_PATH='$PROTON_PATH'

# Launch the main script
"$(cd "$DIR_CO_OP" && pwd)/Co-Op-On-Linux.sh"
EOF

chmod +x "$DIR_CO_OP/profiles/$name.sh" || error_exit "Could not make profile script executable"

$DIALOG --info --text="Profile '$name' created successfully! To load it, go to the profiles folder and execute its script"
