{ config, lib, pkgs, ... }:
let
  wireguard = import ../../common/funcs/wireguard.nix { inherit config; };
in
wireguard.service "ldn" "wireguard-ldn"

