{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common
    ./hardware-configuration.nix
    ./syncthing.nix
  ];

  # NixOps
  # deployment = {
  #   targetHost = "dev.terra.fap.no";
  # };

  environment.systemPackages = with pkgs; [
    parted
  ];


  networking = {
    hostName = "dev";
    nameservers = [
      "8.8.8.8"
    ];
    defaultGateway = "10.60.0.1";
    defaultGateway6 = "";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      ens3 = {
        ipv4.addresses = [
          { address = "10.60.0.44"; prefixLength = 24; }
        ];
        ipv4.routes = [{ address = "10.60.0.1"; prefixLength = 32; }];
      };

    };
  };

  services.udev.extraRules = ''
    ATTR{address}=="52:54:00:7e:ff:c8", NAME="ens3"
  '';

  boot.cleanTmpDir = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
