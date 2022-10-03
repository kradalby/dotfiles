{
  config,
  pkgs,
  lib,
  ...
}: let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.ldn;
in
  (import ../../common/funcs/tailscale.nix {inherit config pkgs lib;}).tailscale
  {
    preAuthKey = "tskey-kXJqZK5CNTRL-aPGtW6DLH4XqZ1PBPMDay"; # onetime key
    reauth = false;
    exitNode = true;
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:ldn" "tag:gateway" "tag:server"];
  }
