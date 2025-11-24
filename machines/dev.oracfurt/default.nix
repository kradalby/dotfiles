{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../common
    ./hardware-configuration.nix

    ../../common/containers.nix

    ../../common/consul-server.nix
    ../../common/tailscale.nix

    ./restic.nix
    ./tailscale-headscale.nix
    ./syncthing.nix
    # ./attic.nix
    ./proton.nix
    ./mealie.nix
  ];

  my.wan = "enp0s3";
  my.lan = "enp1s0";

  networking = {
    hostName = "dev";
    domain = "oracfurt.fap.no";
    usePredictableInterfaceNames = lib.mkForce true;

    nat = {
      enable = true;
      externalInterface = config.my.wan;
      internalIPs = ["10.0.0.0/8"];
      internalInterfaces = [config.my.lan "iot"];
      forwardPorts = [
        {
          sourcePort = 64322;
          destination = "10.67.0.1:22";
          proto = "tcp";
        }
        {
          sourcePort = 500;
          destination = "10.67.0.1:51820";
          proto = "udp";
        }
        {
          sourcePort = 4500;
          destination = "10.67.0.1:51820";
          proto = "udp";
        }
      ];
    };

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
        config.services.tailscale.port
        51820 # WireGuard
      ];

      trustedInterfaces = [config.my.lan];
    };
  };

  systemd.network = {
    enable = true;
    
    wait-online.ignoredInterfaces = ["tailscale0" "wg0"];

    networks = {
      "10-wan" = {
        matchConfig.Name = config.my.wan;
        DHCP = "yes";
      };

      "10-lan" = {
        matchConfig.Name = config.my.lan;
        address = ["10.67.0.1/24"];
        DHCP = "no";
      };
    };
  };

  services.tailscale = let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib config;};
    wireguardConfig = wireguardHosts.servers.oraclefurt;
  in {
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:oracfurt" "tag:gateway" "tag:server"];
  };

  services.wireguard = {
    enable = true;
    nodeName = "oraclefurt";
    secretName = "wireguard-oracfurt";
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
}
