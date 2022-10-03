{
  config,
  pkgs,
  lib,
  ...
}: let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.oracleldn;
in
  (import ../../common/funcs/tailscale.nix {inherit config pkgs lib;}).tailscale
  {
    preAuthKey = "tskey-kLeAwF3CNTRL-ECKYbf5nEY17n2hwGokBn3"; # onetime key
    reauth = false;
    exitNode = true;
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:oracldn" "tag:gateway" "tag:server"];
  }
