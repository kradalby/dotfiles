{ config, lib, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config; };
  helpers = import ../../common/funcs/helpers.nix { inherit lib; };

  directories = [
    "/etc/nixos"
    "/var/lib/zigbee2mqtt"
    "/var/lib/homebridge"
    "/var/lib/unifi/data/backup"
  ];
in

helpers.recursiveMerge [
  (restic.backupJob "tjoda" "restic-ldn-home-token" directories)
  (restic.backupJob "terra" "restic-ldn-home-token" directories)
]
