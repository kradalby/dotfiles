{
  config,
  pkgs,
  lib,
  ...
}: let
  wireguardHosts = import ../../metadata/wireguard.nix;
  wireguardConfig = wireguardHosts.servers.oraclefurt;
in
  (import ../../common/funcs/tailscale.nix {inherit config pkgs lib;}).tailscale
  "dev.oracfurt"
  "https://headscale.kradalby.no"
  "3318d1e44dd610a048d05111cab71eae632cf3d6400c19ec" # onetime key
  
  true
  wireguardConfig.additional_networks
