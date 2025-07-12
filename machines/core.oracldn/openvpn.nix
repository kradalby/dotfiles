{
  pkgs,
  config,
  lib,
  ...
}: let
  s = import ../../metadata/ipam.nix {inherit lib config;};
  site = s.sites.oracldn;
in ((import ../../common/funcs/openvpn.nix {inherit config pkgs lib;}).server site)
