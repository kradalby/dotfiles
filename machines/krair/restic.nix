{
  config,
  pkgs,
  lib,
  stdenv,
  ...
}: let
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
    name = "krair";
    secret = "restic-krair-token";
    owner = "kradalby";
    inherit site;
    paths = basePaths;
  };

  cfgJotta = {
    name = "jotta";
    secret = "restic-krair-token";
    repository = "rclone:Jotta:4e8bb5107054b95e58d809060cb72911";
    paths = jottaPaths;
  };
in {
  imports = [../../modules/restic.nix];

  # Example:
  # services.restic.jobs = {
  #   jotta = {
  #     repository = "rclone:Jotta:4e8bb5107054b95e58d809060cb72911";
  #     secret = "restic-krair-token";
  #     paths = jottaPaths;
  #     owner = "kradalby";
  #   };
  # };
}
