#!/usr/bin/env bash

# Use this as a osx service.
# Edit for own needs.
#
# Install:
# Open Automater.app
# Create Service
# Change to no input and add Run Shell Script
# Paste path to script ( make sure it is executable )
# Save and add a shortcut to it under System Preferences > Keyboard > Shortcuts

url=https://screenshots.kradalby.no/
filename=`date '+%Y%m%d%H%M%S'`.png
path=~/Pictures/ss/
mkdir -p $path
screencapture -o -i $path$filename
scp -i ~/Sync/ssh/kramacbook/id_ed25519 -v $path$filename root@storage.terra.fap.no:/storage/nfs/k8s/screenshots/.
printf $url$filename | pbcopy
