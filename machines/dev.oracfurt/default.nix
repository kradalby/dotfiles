{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/containers.nix

    ../../common/tailscale.nix
    ../../common/oci-gateway.nix
    ../../common/tsnixcache-client.nix

    ./garnix-builder.nix
    ./restic.nix
    ./syncthing.nix
    ./proton.nix
    ./cook.nix
    ./atuin.nix
    ./litestream.nix
  ];

  # Disable built-in tsidp module in favor of the flake input
  disabledModules = [ "services/security/tsidp.nix" ];

  my.wan = "enp0s3";
  my.lan = "enp1s0";

  networking = {
    hostName = "dev";
    domain = "oracfurt.fap.no";
    usePredictableInterfaceNames = lib.mkForce true;

    interfaces.${config.my.wan} = {
      useDHCP = true;
      # Stable reserved public IP (129.159.30.250) NATs to this
      # secondary private IP; DHCP keeps the primary private IP,
      # which carries the ephemeral public IP.
      ipv4.addresses = [
        {
          address = "192.168.122.10";
          prefixLength = 24;
        }
      ];
      ipv6.addresses = [
        {
          address = "2603:c020:8026:db00::10";
          prefixLength = 64;
        }
      ];
    };
    interfaces.${config.my.lan} = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.67.0.1";
          prefixLength = 24;
        }
      ];
    };

  };

  my.ociGateway = {
    enable = true;
    gatewayAddress = "10.67.0.1";
  };

  services.tailscale = {
    advertiseRoutes = [ "10.67.0.0/16" ];
    tags = [
      "tag:backup-client"
      "tag:dev"
      "tag:gateway"
      "tag:server"
      # garnix aarch64 build target — see machines/garnix + the kradalby.no ACL
      # (src tag:garnix -> dst tag:garnix-builder). Also the cache-push identity,
      # so oracfurt no longer relies on tag:dev being in the tsnixcache push src.
      "tag:garnix-builder"
    ];
  };

  services.tsidp.enable = true;

  virtualisation.docker.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?

  # nixos-raspberrypi prebuilt kernel/firmware. Scoped here, not fleet-wide:
  # trusting the key lets that cache substitute any path, so only hosts that
  # actually build rpi closures carry it.
  nix.settings = {
    substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };
}
