{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/rpi4-configuration.nix

    ./mediamtx.nix

    ./tailscale.nix
  ];

  age.secrets.ldn-wifi = {
    file = ../../secrets/ldn-wifi.age;
  };

  networking = {
    hostName = "eye";
    domain = "ldn.fap.no";
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
  system.stateVersion = "24.05";
}
