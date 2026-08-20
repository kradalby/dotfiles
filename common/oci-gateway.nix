# Shared NAT-gateway shape for the public Oracle VMs (core.oracldn,
# dev.oracfurt): WAN NAT for the site subnet, a pinned WAN firewall surface,
# and the OCI IPv6 RA sysctls. Was copy-pasted between the two hosts and had
# already drifted.
{
  config,
  lib,
  ...
}:
let
  cfg = config.my.ociGateway;
in
{
  options.my.ociGateway = {
    enable = lib.mkEnableOption "OCI public NAT gateway profile";

    gatewayAddress = lib.mkOption {
      type = lib.types.str;
      description = "This gateway's address on the site subnet (SSH forward target), e.g. 10.66.0.1.";
    };

    extraUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      description = "Extra WAN UDP ports (the lists are mkForce'd — additions must go here).";
    };

    extraTrustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Interfaces trusted in addition to the LAN (e.g. docker0).";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.nat = {
      enable = true;
      externalInterface = config.my.wan;
      internalIPs = [ "10.0.0.0/8" ];
      internalInterfaces = [
        config.my.lan
        "iot"
      ];
      forwardPorts = [
        {
          sourcePort = 64322;
          destination = "${cfg.gatewayAddress}:22";
          proto = "tcp";
        }
      ];
    };

    networking.firewall = {
      enable = lib.mkForce true;
      # mkForce: gateway machines pin their WAN surface — module-contributed
      # global opens (openFirewall) must not widen it. Interface-scoped opens
      # (the tailscale0 exporter pattern) are unaffected.
      allowedTCPPorts = lib.mkForce [
        22 # SSH
        80 # HTTP
        443 # HTTPS
      ];

      allowedUDPPorts = lib.mkForce (
        [
          443 # HTTPS
          config.services.tailscale.port
        ]
        ++ cfg.extraUDPPorts
      );

      trustedInterfaces = [ config.my.lan ] ++ cfg.extraTrustedInterfaces;
    };

    boot.kernel.sysctl = {
      # IPv6 default route comes from OCI router advertisements; accept_ra=2
      # keeps that working with forwarding enabled. No SLAAC (autoconf=0):
      # OCI only routes addresses explicitly assigned to the VNIC.
      "net.ipv6.conf.${config.my.wan}.accept_ra" = 2;
      "net.ipv6.conf.${config.my.wan}.autoconf" = 0;
    };
  };
}
