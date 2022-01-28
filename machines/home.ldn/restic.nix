{ pkgs, config, lib, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  directories = [
    "/etc/nixos"
    "/var/lib/zigbee2mqtt"
    "/var/lib/homebridge"
    "/var/lib/unifi/data/backup"
  ];
in
lib.mkMerge [
  (restic.backupJob config.networking.fqdn "tjoda" "restic-home-ldn-token" directories)
  (restic.backupJob config.networking.fqdn "terra" "restic-home-ldn-token" directories)
]
