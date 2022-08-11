{ pkgs, config, lib, ... }:
let
  s = import ../../metadata/sites.nix { inherit lib config; };
  site = s.sites.tjoda;
in
((import ../../common/funcs/openvpn.nix { inherit config pkgs lib; }).server site)
