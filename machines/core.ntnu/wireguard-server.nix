{ config, lib, pkgs, ... }:
let
  wgFuncs = import ../../common/funcs/wireguard.nix;
in
{

  sops.secrets.wireguard-ntnu = { };
  networking.wireguard = {
    enable = true;
    interfaces = {
      wg0 = wgFuncs.server "ntnu" config.sops.secrets.wireguard-ntnu.path;
    };
  };

  networking.firewall.allowedUDPPorts = [ config.networking.wireguard.interfaces.wg0.listenPort ];

}

