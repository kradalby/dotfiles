{ pkgs, config, lib, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  directories = [
    "/etc/nixos"
    "/var/lib/headscale"
  ];
in
lib.mkMerge [
  (restic.backupJob config.networking.fqdn "tjoda" "restic-headscale-oracldn-token" directories)
  (restic.backupJob config.networking.fqdn "terra" "restic-headscale-oracldn-token" directories)
]
