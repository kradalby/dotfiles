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
    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/containers.nix

    ../../common/tailscale.nix
    ../../common/oci-gateway.nix
    ../../common/tsnixcache-client.nix

    ./restic.nix
    ./kuma.nix
    ./monitoring.nix
    ./slo.nix
    ./grafana.nix
    ./postgres.nix
    ./stirling-pdf.nix
    ./litestream.nix

    ./headscale.nix
    ./umami.nix
    ./golink.nix
    ./webpage.nix
    ./hvor.nix
    ./exporter.nix
  ];

  my.wan = "enp0s3";
  my.lan = "enp1s0";

  networking = {
    hostName = "core";
    domain = "oracldn.fap.no";
    usePredictableInterfaceNames = lib.mkForce true;
    interfaces = {
      "${config.my.wan}" = {
        useDHCP = true;
        # Stable reserved public IP (152.67.129.235) NATs to this
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
            address = "2603:c020:c013:2600::10";
            prefixLength = 64;
          }
        ];
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

  };

  my.ociGateway = {
    enable = true;
    gatewayAddress = "10.66.0.1";
    # headscale DERP STUN. headscale.nix also opens this, but the gateway
    # lists are mkForce'd — extra ports must live here to take effect.
    extraUDPPorts = [ 3478 ];
    extraTrustedInterfaces = [ "docker0" ];
  };

  services.tailscale = {
    advertiseRoutes = [ "10.66.0.0/16" ];
    tags = [
      "tag:backup-client"
      "tag:gateway"
      "tag:monitoring"
      "tag:server"
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
