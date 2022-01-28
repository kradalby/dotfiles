{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/acme.nix
    ../../common/nginx.nix


    ./restic.nix
    ./wireguard.nix
    ./headscale.nix
  ];

  my.lan = "ens3";

  networking = {
    hostName = "headscale";
    domain = "oracldn.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      "${config.my.lan}" = {
        useDHCP = true;
      };
    };

    firewall = {
      enable = lib.mkForce true;
      # This is a special override for gateway machines as we 
      # dont want to use "openFirewall" here since it makes
      # everything world available.
      allowedTCPPorts = lib.mkForce [
        22 # SSH
        80 # HTTP
        443 # HTTPS
      ];

      allowedUDPPorts = lib.mkForce [
        443 # HTTPS
        # config.services.tailscale.port
        # config.networking.wireguard.interfaces.wg0.listenPort
      ];
    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="02:00:17:02:df:1c", NAME="ens3"
  '';


  services.consul.extraConfig.retry_join = [ ];


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
