{
  config,
  lib,
  pkgs,
  ...
}: let
  wireguard = import ../../common/funcs/wireguard.nix {inherit config lib;};
in
  wireguard.serverService "terra" "wireguard-terra"
