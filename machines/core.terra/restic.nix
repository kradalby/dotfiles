{ pkgs
, config
, lib
, ...
}:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  paths = [
    "/root"
    "/etc/nixos"
    "/storage/backup"
    "/storage/libraries"
    "/storage/pictures"
    "/storage/software"
    "/storage/sync"
    # "/storage/restic"
    config.services.postgresqlBackup.location
  ];

  cfg = {
    name = "jotta";
    secret = "restic-core-terra-token";
    repository = "rclone:Jotta:3cee607f10a34c3fd67e4b292fda606f";
    inherit paths;
  };
in
lib.mkMerge [
  (restic.commonJob cfg)
]
