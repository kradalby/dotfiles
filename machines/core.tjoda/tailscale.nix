{ config, pkgs, lib, ... }:
let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.tjoda;
in
((import ../../common/funcs/tailscale.nix { inherit config pkgs lib; }).tailscale
  "core.tjoda"
  "https://headscale.kradalby.no"
  "38c9b097d3a39b17d8c13ec5efff598fa9525aae8770654d" # onetime key
  true
  wireguardConfig.additional_networks)
