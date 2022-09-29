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
    preAuthKey = "tskey-kbqvY53CNTRL-Z7Vy6nxF4BcuQoRc581VsZ"; # onetime key
    reauth = true;
    exitNode = true;
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:ldn" "tag:gateway"];
  }
