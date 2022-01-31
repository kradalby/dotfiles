{ config, pkgs, lib, ... }:
let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.clients.headscale;
in
((import ../../common/funcs/tailscale.nix { inherit config pkgs lib; }).tailscale
  "headscale.oracldn"
  "https://headscale.kradalby.no"
  "7f0e5d7862606ce31537317ad22abe6e18ca3c099926e3ae" # onetime key
  true
  wireguardConfig.additional_networks)

