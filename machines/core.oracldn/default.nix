{
  config,
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

    ../../common/coredns.nix
    ../../common/miniupnp.nix
    ../../common/minio.nix
    ../../common/tailscale.nix

    ./restic.nix
    ./kuma.nix
    ./monitoring.nix
    ./loki.nix
    ./grafana.nix
    # ./step-ca.nix
    ./postgres.nix
    ./stirling-pdf.nix
    ./litestream.nix

    ./headscale.nix
    ./umami.nix
    ./golink.nix
    ./webpage.nix
    ./hvor.nix
    ./exporter.nix
    ./monica.nix
  ];

  my.wan = "enp0s3";
  my.lan = "enp1s0";
  my.coredns.bind = ["10.66.0.1"];

  networking = {
    hostName = "core";
    domain = "oracldn.fap.no";
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      "${config.my.wan}" = {
        useDHCP = true;
      };

      ${config.my.lan} = {
        useDHCP = false;
        ipv4.addresses = [
          {
            address = "10.66.0.1";
            prefixLength = 24;
          }
        ];
        tempAddress = "disabled";
      };
    };

    nat = {
      enable = true;
      externalInterface = config.my.wan;
      internalIPs = ["10.0.0.0/8"];
      internalInterfaces = [config.my.lan "iot"];
      forwardPorts = [
        {
          sourcePort = 64322;
          destination = "10.66.0.1:22";
          proto = "tcp";
        }
        {
          sourcePort = 500;
          destination = "10.66.0.1:51820";
          proto = "udp";
        }
        {
          sourcePort = 4500;
          destination = "10.66.0.1:51820";
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

        21115
        21116
        21117
        21118
      ];

      allowedUDPPorts = lib.mkForce [
        443 # HTTPS
        config.services.tailscale.port
        51820 # WireGuard
      ];

      trustedInterfaces = [config.my.lan "docker0"];
    };
  };

  services.tailscale = let
    wireguardHosts = import ../../metadata/wireguard.nix {inherit lib;};
    wireguardConfig = wireguardHosts.servers.oracleldn;
  in {
    advertiseRoutes = wireguardConfig.additional_networks;
    tags = ["tag:oracldn" "tag:gateway" "tag:server"];
  };

  services.wireguard = {
    enable = true;
    nodeName = "oracleldn";
    secretName = "wireguard-oracldn";
    refreshOnIdle = {
      enable = true;
      peers = ["tjoda"];
      maxAgeSeconds = 21600;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
