{
  pkgs,
  config,
  lib,
  ...
}: let
  restic = import ../../common/funcs/restic.nix {inherit config lib pkgs;};

  paths = [
    "/var/lib/unifi"
  ];

  cfg = site: {
    secret = "restic-unifi-ldn-token";
    site = site;
    paths = paths;
  };
in
  lib.mkMerge [
    (restic.backupJob (cfg "tjoda"))
    (restic.backupJob (cfg "terra"))
  ]
