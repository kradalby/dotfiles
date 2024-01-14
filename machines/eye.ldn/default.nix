{
  config,
  flakes,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix

    ../../common/rpi4-configuration.nix

    ./mediamtx.nix

    # ./tailscale.nix
    # ./tailscale-headscale.nix
  ];

  age.secrets.ldn-wifi = {
    file = ../../secrets/ldn-wifi.age;
  };

  networking = {
    hostName = "eye";
    domain = "ldn.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      "eth0" = {
        useDHCP = true;
      };

      "wlan0" = {
        useDHCP = true;
      };
    };

    wireless = {
      enable = true;
      environmentFile = config.age.secrets.ldn-wifi.path;
      networks = {
        "_kad".psk = "@PSK_UNDERSCORE_KAD@";
      };
    };
  };

  monitoring.smartctl.devices = ["/dev/sda"];
  system.stateVersion = "20.09"; # Did you read the comment?
}
