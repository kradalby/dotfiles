{
  pkgs,
  config,
  lib,
  ...
}: let
  restic = import ../../common/funcs/restic.nix {inherit config lib pkgs;};
  helpers = import ../../common/funcs/helpers.nix {inherit pkgs lib;};

  paths = [
    "/root"
    "/etc/nixos"
    "/var/lib/unifi/data/backup"
    "/storage/backup"
    "/storage/libraries"
    "/storage/pictures"
    "/storage/software"
    "/storage/sync"
    # "/storage/restic"
  ];

  cfg = {
    name = "jotta";
    secret = "restic-core-tjoda-token";
    repository = "rclone:Jotta:1d444f272fa766893d9a06cc4d392cd5";
    inherit paths;
  };
in
  lib.mkMerge [
    (restic.commonJob cfg)
  ]
