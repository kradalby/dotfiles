{
  config,
  lib,
  pkgs,
  ...
}: let
  wireguard = import ../../common/funcs/wireguard.nix {inherit config lib pkgs;};
in
  wireguard.serverService "oraclefurt" "wireguard-oracfurt"
