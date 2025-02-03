{
  config,
  pkgs,
  lib,
  ...
}: let
  lan = "enp0s31f6";
  maxVMs = 64;
in {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix
    ../../common/tailscale.nix

    ../../common/consul.nix

    ./tailscale-headscale.nix

    ./microvm.nix
    # ./k3s.nix
  ];

  my.lan = lan;

  networking = {
    hostName = "lenovo";
    domain = "ldn.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      "enp0s31f6" = {
        useDHCP = true;
      };
    };

    useNetworkd = true;

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
      ];

      trustedInterfaces = [config.my.lan];
    };

    nat = {
      enable = true;
      internalIPs = ["172.16.0.0/24"];
      # Change this to the interface with upstream Internet access
      externalInterface = lan;
    };
  };

  systemd.network.networks = builtins.listToAttrs (
    map (index: {
      name = "30-vm${toString index}";
      value = {
        matchConfig.Name = "vm${toString index}";
        # Host's addresses
        address = [
          "172.16.0.0/32"
          "fec0::/128"
        ];
        # Setup routes to the VM
        routes = [
          {
            Destination = "172.16.0.${toString index}/32";
          }
          {
            Destination = "fec0::${lib.toHexString index}/128";
          }
        ];
        # Enable routing
        networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
      };
    }) (lib.genList (i: i + 1) maxVMs)
  );

  services.tailscale = {
    tags = ["tag:ldn" "tag:server"];
  };

  virtualisation.docker.enable = lib.mkForce false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
