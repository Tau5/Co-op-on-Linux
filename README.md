# Co-op-on-Linux (CO-OL)

This program allows you to play on splitscreen with up to 4 players on any game
that supports LAN play (For example: Terraria, Need for Speed, etc.)

# Installation

## Standard linux

1. Download the latest release
2. Extract the release file
3. Install `sway`, `firejail` and `zenity`
4. Read Usage section

## Steam Deck (SteamOS)

1. Download the latest release
2. Extract the release file
3. Run install-steamos.sh
4. Read Usage section

# Usage

CO-OL uses a profile system, each profile describes the command to execute and the resolution of the screen.

A profile will be created as a script file, which you can then execute (or add to steam or your menu)
and play the game configured on the profile

## Creating a profile

To create a profile execute the `create-new-profile.sh` script and follow the instructions:

- Game executable
:   Select the executable for the game, you can also just write a command to execute 
   (This is useful for wine games)
 
- Resolution
:   Specify the total resolution of the screen, this will be then divided for the game instances

- Name
:   The name of the profile

## Using a profile

> [!NOTE]
> If you have added a profile as a Non-Steam Game on Steam make sure to disable Steam Input or 
> CO-OL won't detect the controllers!

Your profiles are in the `profiles` directory, just execute the script for the profile you want,
a window will appear to select the controllers you are going to use, just press X/A/B on each of the
controllers you are going to use, and press START when you are finished selecting controllers

CO-OL will then take care of launching the game instances

# Tested Games

DRM-free games should work as long as the game doesn't prevent you form run it more than one time
, for Steam games it depends on the DRM, Some games works Some don't 
(Those could probably work using Goldberg emulator)

| Game     | Status  | Command                                                                |
|----------|---------|------------------------------------------------------------------------|
| Terraria | Works   | $HOME/.local/share/Steam/steamapps/common/Terraria/Terraria.bin.x86_64 |
|          |         |                                                                        |

