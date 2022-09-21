{
  config,
  lib,
  pkgs,
  ...
}: let
  wireguard = import ../../common/funcs/wireguard.nix {inherit config lib;};
in
  wireguard.serverService "ntnu" "wireguard-ntnu"
