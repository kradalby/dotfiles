{ config, lib, pkgs, ... }:
let
  wireguard = import ../../common/funcs/wireguard.nix { inherit config lib; };
in
wireguard.service "ldn" "wireguard-ldn"

