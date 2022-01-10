{ config, pkgs, lib, ... }:
let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.ntnu;
in
((import ../../common/funcs/tailscale.nix { inherit config pkgs lib; }).tailscale
  "core.ntnu"
  "https://headscale.kradalby.no"
  "88ecfd79aaa87d4795d4016f26b58713d6be27167384ac2a" # onetime key
  true
  wireguardConfig.additional_networks)

