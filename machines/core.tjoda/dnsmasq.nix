{
  config,
  lib,
  ...
}: {
  # Allow DNS from selskap
  networking.firewall.interfaces."selskap".allowedUDPPorts = [67 68];

  services.dnsmasq = {
    enable = true;

    # don't use it locally for dns
    resolveLocalQueries = lib.mkDefault false;
    settings = let
      lan = config.my.lan;
      selskap = "selskap";
    in {
      interface = [
        lan
        selskap
      ];

      # disable dns
      port = 0;

      dhcp-range = [
        "interface:${lan},10.62.0.171,10.62.0.250,255.255.255.0,12h"
        "interface:${selskap},192.168.200.100,192.168.200.200,255.255.255.0,12h"
      ];

      dhcp-option = [
        # gateway
        "interface:${lan},option:router,10.62.0.1"
        "interface:${selskap},option:router,192.168.200.1"

        # dns server
        # "interface:${lan},option:dns-server,10.62.0.1"
        # "interface:${selskap},option:dns-server,192.168.200.1"
        "option:dns-server,10.62.0.1"
      ];

      dhcp-option-force = [
        "option:domain-search,tjoda,fap.no,kradalby.no"
      ];

      # static leases
      dhcp-host = builtins.map (machine: "${machine.mac},${machine.hostname},${machine.ipAddress}") config.my.machines;
    };
  };
}
