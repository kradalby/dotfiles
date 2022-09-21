{
  config,
  lib,
  pkgs,
  ...
}: let
  wireguard = import ../../common/funcs/wireguard.nix {inherit config lib;};
in
  wireguard.clientService "storagebassan" "wireguard-storage-bassan"
