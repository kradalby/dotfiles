#!/bin/bash
# Based on https://github.com/sandeel/i3-new-workspace
# Script occupies free workspace with lowest possible number

WS_JSON=$(i3-msg -t get_workspaces)
for i in {1..10} ; do
    if [[ $WS_JSON != *"\"num\":$i"* ]] ; then
        i3-msg workspace number $i
        break
    fi
done
