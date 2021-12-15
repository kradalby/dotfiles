#!/usr/bin/env bash

url=https://screenshots.kradalby.no/
filename=$(date '+%Y%m%d%H%M%S').png
path=~/Pictures/ss/
mkdir -p $path
scrot $path$filename -s
scp -i ~/Sync/ssh/kramacbook/id_ed25519 -v $path$filename root@storage.terra.fap.no:/storage/nfs/k8s/screenshots/.
printf $url$filename | xclip -selection c
