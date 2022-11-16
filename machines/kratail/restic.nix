{
  config,
  flakes,
  pkgs,
  lib,
  stdenv,
  ...
}: let
  restic = import ../../common/funcs/restic.nix {inherit config lib pkgs;};
  helpers = import ../../common/funcs/helpers.nix {inherit pkgs lib;};

  basePaths = [
    # We do not have perms to backup these folders
    # because of macOS magic
    # "$HOME/Desktop"
    # "$HOME/Documents"
    # "$HOME/Downloads"

    # "$HOME/Sync"
    "$HOME/git"
  ];

  jottaPaths =
    basePaths
    ++ [
      "$HOME/Pictures"
    ];

  cfg = site: {
    name = "kratail";
    secret = "restic-kratail-token";
    owner = "kradalby";
    inherit site;
    paths = basePaths;
  };

  cfgJotta = {
    name = "jotta";
    secret = "restic-kratail-token";
    repository = "rclone:Jotta:4e8bb5107054b95e58d809060cb72911";
    paths = jottaPaths;
  };
in
  {
    imports = [../../modules/restic.nix];
  }
  // lib.mkMerge [
    # (restic.commonJob cfgJotta)
    # (restic.backupJob (cfg "tjoda"))
    # (restic.backupJob (cfg "terra"))
  ]
