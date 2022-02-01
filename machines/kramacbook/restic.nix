{ config, flakes, pkgs, lib, stdenv, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  paths = [
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Sync"
    "$HOME/git"
    "$HOME/grit"
    "$HOME/.local"
    "$HOME/.config"
  ];

  cfg = site: {
    name = "kramacbook";
    secret = "restic-kramacbook-token";
    owner = "kradalby";
    site = site;
    paths = paths;
  };


in
{
  imports = [ ../../modules/restic.nix ];
} //
lib.mkMerge [
  (restic.backupJob (cfg "tjoda"))
  (restic.backupJob (cfg "terra"))
]
