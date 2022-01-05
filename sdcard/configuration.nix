{ config, pkgs, lib, ... }:
{

  imports = [
    ../common/ssh.nix
    ../common/users.nix
  ];

  sdImage.compressImage = false;

  networking.useDHCP = true;
  networking.firewall.enable = false;


  nix.trustedUsers = [ "kradalby" ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    permitRootLogin = "yes";

  };

  users = {
    users = {
      kradalby = {
        password = "kradalby";
      };
      root = {
        password = "kradalby";
      };
    };
  };
}
