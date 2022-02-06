{ config, pkgs, lib, ... }:
let
  s = import ../../metadata/sites.nix { inherit lib config; };
in
(import ../../common/funcs/k3s.nix { inherit config pkgs lib; }).agent s.sites.terra
