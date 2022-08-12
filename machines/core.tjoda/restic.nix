{ pkgs, config, lib, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  paths = [
    "/etc/nixos"
    "/var/lib/unifi/data/backup"
  ];

  cfg = site: {
    secret = "restic-core-tjoda-token";
    inherit site;
    inherit paths;
  };
in
lib.mkMerge [
  (restic.backupJob (cfg "tjoda"))
  (restic.backupJob (cfg "terra"))
]
