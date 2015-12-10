#!/bin/bash

# Use this as a osx service.
# Edit for own needs.
# 
# Install:
# Open Automater.app
# Create Service
# Change to no input and add Run Shell Script
# Paste path to script ( make sure it is executable )
# Save and add a shortcut to it under System Preferences > Keyboard > Shortcuts

url=https://kradalby.no/ss/
filename=`date '+%Y%m%d%H%M%S'`.png
path=~/Pictures/ss/
mkdir -p $path
screencapture -o -i $path$filename
scp -v $path$filename onyx:/usr/local/www/kradalby.no/ss/
printf $url$filename | pbcopy
