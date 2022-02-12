{ config, pkgs, lib, ... }:
let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.clients.headscale;
in
((import ../../common/funcs/tailscale.nix { inherit config pkgs lib; }).tailscale
  "core.oracldn"
  "https://headscale.kradalby.no"
  "5d12701404d46e35107e40a8ea21bfdefffa46099664c74b" # onetime key
  true
  wireguardConfig.additional_networks)
