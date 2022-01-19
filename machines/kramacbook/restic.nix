{ config, flakes, pkgs, lib, stdenv, ... }:
let
  restic = import ../../common/funcs/restic.nix { inherit config lib pkgs; };
  helpers = import ../../common/funcs/helpers.nix { inherit pkgs lib; };

  directories = [
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

in
{
  imports = [ ../../modules/restic.nix ];
} //
lib.mkMerge [
  (restic.backupJob "kramacbook" "tjoda" "restic-kramacbook-token" directories)
  (restic.backupJob "kramacbook" "terra" "restic-kramacbook-token" directories)
]
