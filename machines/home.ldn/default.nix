{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../common/base.nix
    ../../profiles/server.nix
    ../../common/avahi.nix # owntone requires avahi-daemon.socket
    ../../common/incus-vm-ldn.nix

    ../../common/containers.nix
    ../../common/tailscale.nix

    ./restic.nix
    ./mqtt.nix
    ./zigbee2mqtt.nix
    ./iSponsorBlockTV.nix
    ./nefit-homekit.nix
    ./tasmota-homekit.nix
    ./z2m-homekit.nix
    ./owntone.nix
  ];

  # Merges with the tag:server baseline from incus-vm-ldn.nix. tag:homeauto
  # gates the mqtt ports and approves the owntone/p3/z2m VIP advertisements.
  services.tailscale.tags = [
    "tag:backup-client"
    "tag:homeauto"
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
