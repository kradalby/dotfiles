{
  config,
  pkgs,
  lib,
  flakes,
  ...
}: let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.terra;
in
  (import ../../common/funcs/tailscale.nix {inherit config pkgs lib flakes;}).tailscale
  {
    reauth = false;
    exitNode = true;
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:terra" "tag:gateway" "tag:server"];
  }
