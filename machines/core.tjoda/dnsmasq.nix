{
  config,
  lib,
  ...
}: {
  my.machines = [
    {
      hostname = "hus-kontor-printer";
      ipAddress = "10.62.0.9";
      mac = "78:e7:d1:a7:a9:55";
    }
    {
      hostname = "love-kontor-printer";
      ipAddress = "10.62.0.6";
      mac = "60:12:8b:d2:ee:72";
    }

    # Unifi networking
    {
      hostname = "hus-kontor-switch";
      ipAddress = "10.62.0.110";
      mac = "b4:fb:e4:24:f9:61";
    }
    {
      hostname = "love-loft-switch";
      ipAddress = "10.62.0.111";
      mac = "ac:8b:a9:b0:db:63";
    }
    {
      hostname = "love-kontor-switch";
      ipAddress = "10.62.0.112";
      mac = "74:ac:b9:d7:a4:23";
    }
    {
      hostname = "love-scene-switch";
      ipAddress = "10.62.0.113";
      mac = "f4:92:bf:a3:6a:59";
    }
    {
      hostname = "bryggerhus-switch";
      ipAddress = "10.62.0.114";
      mac = "f4:92:bf:a3:6a:23";
    }
    {
      hostname = "hus-kontor-ap";
      ipAddress = "10.62.0.120";
      mac = "74:ac:b9:63:2f:81";
    }
    {
      hostname = "hus-spisestue-ap";
      ipAddress = "10.62.0.121";
      mac = "74:ac:b9:c6:50:e7";
    }
    {
      hostname = "love-scene-ap";
      ipAddress = "10.62.0.122";
      mac = "fc:ec:da:a6:39:3b";
    }
    {
      hostname = "love-selskap-ap";
      ipAddress = "10.62.0.123";
      mac = "04:18:d6:86:72:89";
    }
    {
      hostname = "love-lager-ap";
      ipAddress = "10.62.0.124";
      mac = "04:18:d6:86:73:1f";
    }
    {
      hostname = "bryggerhus-ap";
      ipAddress = "10.62.0.125";
      mac = "e0:63:da:25:cc:1e";
    }

    # Sonos
    {
      hostname = "hus-kjokken-sonos";
      ipAddress = "10.62.0.140";
      mac = "B8:E9:37:AE:5B:E4";
    }
    {
      hostname = "hus-salong-sonos";
      ipAddress = "10.62.0.141";
      mac = "B8:E9:37:AE:5B:40";
    }
    {
      hostname = "hus-spisestue-sonos";
      ipAddress = "10.62.0.142";
      mac = "B8:E9:37:AE:5A:22";
    }
    {
      hostname = "hus-kontor-sonos";
      ipAddress = "10.62.0.143";
      mac = "B8:E9:37:AE:5A:6C";
    }
    {
      hostname = "hus-gang-sonos";
      ipAddress = "10.62.0.144";
      mac = "B8:E9:37:AE:5B:C8";
    }
    {
      hostname = "hus-hage-sonos";
      ipAddress = "10.62.0.145";
      mac = "B8:E9:37:AE:5B:AC";
    }

    # Sonos låve
    {
      hostname = "love-kontor-bridge-sonos";
      ipAddress = "192.168.200.140";
      mac = "b8:e9:37:14:51:14";
    }
    {
      hostname = "love-salong-sonos";
      ipAddress = "192.168.200.141";
      mac = "B8:E9:37:91:29:1C";
    }
    {
      hostname = "love-spisestue-sonos";
      ipAddress = "192.168.200.142";
      mac = "B8:E9:37:93:0D:24";
    }
    {
      hostname = "love-dansegulv-sonos";
      ipAddress = "192.168.200.143";
      mac = "B8:E9:37:91:29:26";
    }

    # TODO: Love loft sonos?
    # {
    #   hostname = "love-dansegulv-sonos";
    #   ipAddress = "192.168.200.14";
    #   mac = "B8:E9:37:91:29:26";
    # }

    # Atlas probe
    {
      hostname = "atlas-probe";
      ipAddress = "192.168.200.101";
      mac = "02:01:eb:ef:a0:e9";
    }
  ];

  # Allow DNS from selskap
  networking.firewall.interfaces."selskap".allowedUDPPorts = [67 68];

  services.dnsmasq = {
    enable = true;

    # don't use it locally for dns
    resolveLocalQueries = lib.mkDefault false;
    settings = let
      inherit (config.my) lan;
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
        "interface:${selskap},192.168.200.171,192.168.200.250,255.255.255.0,12h"
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
