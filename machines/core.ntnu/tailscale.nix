{
  config,
  pkgs,
  lib,
  ...
}: let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.ntnu;
in (import ../../common/funcs/tailscale.nix {inherit config pkgs lib;}).tailscale
  {
    preAuthKey = ""; # onetime key
    reauth = false;
    exitNode = true;
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:ntnu" "tag:gateway" "tag:server"];
  }
