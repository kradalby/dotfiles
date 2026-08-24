# Global /etc/tmux.conf. Replaces the old home-manager programs.tmux module:
# tmux is a system package (pkgs/base.nix) and reads this as its system config.
# Imported by common/base.nix (every NixOS box) and Darwin's kradalby-base.nix.
# `ac`'s `tmux -L <socket>` servers pick it up at startup.
{
  pkgs,
  lib,
  ...
}:
{
  environment.etc."tmux.conf".text = import ./tmux-conf.nix { inherit pkgs lib; };
}
