{
  lib,
  config,
  ...
}: let
  maxVMs = 5;
in {
  networking = {
    hostId = "007f0200";
    hostName = "lenovo";
    domain = "ldn.fap.no";

    # Use systemd-networkd for configuration. Forcibly disable legacy DHCP
    # client.
    useNetworkd = true;
    useDHCP = false;

    firewall = {
      enable = lib.mkForce false;
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
      externalInterface = "lan0";
    };
  };

  # Use resolved for local DNS lookups, querying through CoreDNS.
  services.resolved = {
    enable = true;
    domains = ["dalby.ts.net"];
    extraConfig = ''
      DNS=::1 127.0.0.1
      DNSStubListener=no
    '';
  };

  systemd = {
    # Manage network configuration with networkd.
    network = {
      enable = true;

      config.networkConfig.SpeedMeter = "yes";

      networks =
        {
        }
        // (builtins.listToAttrs (
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
        ));
    };

    # Tailscale readiness and DNS tweaks.
    # Ignore wan1 as it is only available if my iPhone
    # is broadcasting a hotspot
    network.wait-online.ignoredInterfaces = ["tailscale0" "wg0" "wan1"];
    services.tailscaled.after = ["network-online.target" "systemd-resolved.service"];
  };
}
