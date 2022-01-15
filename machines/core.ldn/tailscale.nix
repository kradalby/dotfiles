{ config, pkgs, lib, ... }:
let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.ldn;
in
((import ../../common/funcs/tailscale.nix { inherit config pkgs lib; }).tailscale
  "core.ldn"
  "https://headscale.kradalby.no"
  "e342d42fd773376f936d592375c6e423e419da09ad9c730b" # onetime key
  true
  wireguardConfig.additional_networks)

