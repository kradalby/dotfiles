{ pkgs, config, lib, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  paths = [
    "/etc/nixos"
    "/var/lib/zigbee2mqtt"
    "/var/lib/homebridge"
    "/var/lib/unifi/data/backup"
  ];

  cfg = site: {
    secret = "restic-home-ldn-token";
    site = site;
    paths = paths;
  };
in
lib.mkMerge [
  (restic.backupJob (cfg "tjoda"))
  (restic.backupJob (cfg "terra"))
]
