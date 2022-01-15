{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix


    ./restic.nix
    ./mqtt.nix
    ./zigbee2mqtt.nix
    ./homebridge.nix
    ./unifi.nix
  ];

  networking = {
    hostName = "home";
    domain = "ldn.fap.no";
    nameservers = [
      "10.65.0.1"
    ];
    defaultGateway = "10.65.0.1";
    defaultGateway6 = "";
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    useDHCP = false;
    interfaces.eth0 = {
      useDHCP = false;
      ipv4.addresses = [
        { address = "10.65.0.25"; prefixLength = 24; }
      ];
      ipv4.routes = [{ address = "10.65.0.1"; prefixLength = 32; }];
    };
    interfaces.wlan0.useDHCP = false;
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
