{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common
    ./hardware-configuration.nix
  ];

  environment.systemPackages = with pkgs; [
  ];


  networking = {
    hostName = "core";
    domain = "ntnu.fap.no";
    nameservers = [
      "8.8.8.8"
    ];
    defaultGateway = "10.61.0.1";
    defaultGateway6 = "";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      ens224 = {
        ipv4.addresses = [
          { address = "10.61.0.1"; prefixLength = 24; }
        ];
      };

    };
  };

  boot.cleanTmpDir = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
