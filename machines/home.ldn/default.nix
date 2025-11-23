{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common
    ../../common/incus-vm-ldn.nix

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix
    ../../common/tailscale.nix

    ./restic.nix
    ./mqtt.nix
    ./zigbee2mqtt.nix
    ./homebridge.nix
    ./iSponsorBlockTV.nix
    ./nefit-homekit.nix
    ./tasmota-homekit.nix
  ];

  networking = {
    hostName = "home";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.26";
          prefixLength = 24;
        }
      ];
      ipv4.routes = [
        {
          address = "10.65.0.1";
          prefixLength = 32;
        }
      ];
    };
    interfaces.wlan0.useDHCP = false;
    firewall.enable = lib.mkForce false;
  };
}
