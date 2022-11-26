{
  pkgs,
  config,
  lib,
  ...
}: {
  options = {
    my.consulServices = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
    };
  };

  config = {
    services.consul = {
      enable = lib.mkDefault true;
      webUi = lib.mkDefault false;

      extraConfig = {
        node_name = config.networking.hostName;
        server = lib.mkDefault false;
        log_level = "DEBUG";
        datacenter = builtins.replaceStrings [".fap.no"] [""] config.networking.domain;

        retry_join = lib.mkDefault [config.networking.defaultGateway.address];

        # addresses = {
        #   http = "127.0.0.1";
        #   https = "127.0.0.1";
        #   grpc = "127.0.0.1";
        #   dns = ''127.0.0.1'';
        #   # dns = ''{{ GetPrivateInterfaces | exclude "type" "IPv6" | include "network" "10.0.0.0/8" | attr "address" }}'';
        # };
        #
        # advertise_addr_ipv4 = "127.0.0.1";

        bind_addr = lib.mkDefault ''{{ GetPrivateInterfaces | exclude "type" "IPv6" | attr "address" }}'';

        connect = {
          enabled = true;
        };

        services = builtins.attrValues config.my.consulServices;
      };
    };

    networking.firewall.allowedTCPPorts = [
      8600 # DNS server
      # 8500 # HTTP server
      8300 # Server RPC
      8301 # Serf Discovery LAN
      8302 # Serf Discovery WAN
    ];
    networking.firewall.allowedUDPPorts = [
      8600 # DNS server
      8301 # Serf Discovery LAN
      8302 # Serf Discovery WAN
    ];
  };
}
