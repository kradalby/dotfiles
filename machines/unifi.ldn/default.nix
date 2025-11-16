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
    ./unifi.nix
  ];

  networking = {
    hostName = "unifi";
    interfaces."${config.my.lan}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.65.0.24";
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
  };
}
