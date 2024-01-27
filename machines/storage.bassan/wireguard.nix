{
  config,
  lib,
  pkgs,
  ...
}: let
  wireguard = import ../../common/funcs/wireguard.nix {inherit config lib pkgs;};
in
  wireguard.clientService "storagebassan" "wireguard-storage-bassan"
