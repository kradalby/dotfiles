{
  config,
  lib,
  ...
}: {
  my.machines = [
    {
      hostname = "dev";
      ipAddress = "10.65.0.1";
      mac = "dc:a6:32:08:d3:e8";
    }
    {
      hostname = "home";
      ipAddress = "10.65.0.25";
      mac = "dc:a6:32:a8:e8:f9";
    }
    # {
    #   hostname = "dev";
    #   ipAddress = "10.65.0.26";
    #   # Wireless
    #   mac = "28:6b:35:88:11:93";
    # }
    {
      hostname = "lenovo";
      ipAddress = "10.65.0.27";
      mac = "6c:4b:90:2b:c7:d2";
    }
    {
      hostname = "eye";
      ipAddress = "10.65.0.28";
      mac = "dc:a6:32:a8:d3:7e";
    }
    {
      hostname = "kraairm2";
      ipAddress = "10.65.0.50";
      mac = "1c:57:dc:5a:db:ef";
    }
    {
      hostname = "kratail";
      ipAddress = "10.65.0.53";
      mac = "1c:57:dc:5d:3a:71";
    }
    {
      hostname = "kradell";
      ipAddress = "10.65.0.54";
      mac = "9c:b6:d0:da:bd:dd";
    }

    # Network
    {
      hostname = "skap-switch";
      ipAddress = "10.65.0.70";
      mac = "e0:63:da:54:fc:fb";
    }
    {
      hostname = "tv-switch";
      ipAddress = "10.65.0.71";
      mac = "38:94:ed:11:6a:53";
    }
    {
      hostname = "stue-ap";
      ipAddress = "10.65.0.72";
      mac = "e0:63:da:25:cc:1e";
    }

    # Cisco
    {
      hostname = "cisco-skap-ap";
      ipAddress = "10.65.0.73";
      mac = "00:ea:bd:83:f2:02";
    }
    {
      hostname = "cisco-skap-me";
      ipAddress = "10.65.0.74";
      mac = "00:00:5e:00:01:01";
    }
    {
      hostname = "cisco-hjorne-ap";
      ipAddress = "10.65.0.75";
      mac = "68:3b:78:f9:43:70";
    }
    {
      hostname = "skap-tp-switch";
      ipAddress = "10.65.0.76";
      mac = "34:60:F9:AA:FB:52";
    }

    # IoT
    {
      hostname = "vacuum";
      ipAddress = "10.65.0.80";
      mac = "78:11:dc:5f:f6:05";
    }
    {
      hostname = "living-room-corner";
      ipAddress = "10.65.0.82";
      mac = "4c:eb:d6:8f:8a:c1";
    }
    {
      hostname = "living-room-shelf";
      ipAddress = "10.65.0.83";
      mac = "2c:f4:32:6b:b3:57";
    }
    {
      hostname = "living-room-drawer";
      ipAddress = "10.65.0.84";
      mac = "4c:eb:d6:8f:9d:84";
    }
    {
      hostname = "office-light";
      ipAddress = "10.65.0.85";
      mac = "4c:eb:d6:8f:62:9a";
    }
    {
      hostname = "office-eufy-2k";
      ipAddress = "10.65.0.86";
      mac = "04:17:b6:0e:7f:be";
    }
    {
      hostname = "power-p1-meter";
      ipAddress = "10.65.0.87";
      mac = "3c:39:e7:2b:23:38";
    }
    {
      hostname = "office-air";
      ipAddress = "10.65.0.88";
      mac = "4c:eb:d6:97:42:9b";
    }
    {
      hostname = "living-room-tv";
      ipAddress = "10.65.0.89";
      mac = "50:02:91:5e:a5:90";
    }
    {
      hostname = "office-fridge";
      ipAddress = "10.65.0.90";
      mac = "80:64:6f:9d:8c:0e";
    }
    {
      hostname = "office-workstation";
      ipAddress = "10.65.0.91";
      mac = "80:64:6f:9d:8c:c6";
    }
    {
      hostname = "living-room-sofa";
      ipAddress = "10.65.0.92";
      mac = "80:64:6f:9d:8c:49";
    }
    {
      hostname = "office-fan-heater";
      ipAddress = "10.65.0.93";
      mac = "80:64:6f:9d:8c:9b";
    }
    {
      hostname = "staircase-servers";
      ipAddress = "10.65.0.94";
      mac = "a4:cf:12:c3:87:21";
    }
    {
      hostname = "living-room-window-moisture";
      ipAddress = "10.65.0.95";
      mac = "a0:20:a6:06:76:8b";
    }

    # Media
    {
      hostname = "sonos-boost";
      ipAddress = "10.65.0.101";
      mac = "b8:e9:37:0b:5a:7a";
    }
    {
      hostname = "apple-tv";
      ipAddress = "10.65.0.102";
      # Wired
      mac = "90:dd:5d:9b:46:49";
      # Wireless
      # mac = "90:dd:5d:aa:b1:28";
    }
    {
      hostname = "philips-tv";
      ipAddress = "10.65.0.103";
      mac = "70:af:24:b8:4e:7b";
    }
    {
      hostname = "sonos-1";
      ipAddress = "10.65.0.104";
      mac = "34:7e:5c:f0:22:30";
    }
    {
      hostname = "sonos-2";
      ipAddress = "10.65.0.105";
      mac = "78:28:ca:d1:3c:88";
    }
    {
      hostname = "kitchen-homepod";
      ipAddress = "10.65.0.106";
      mac = "e0:2b:96:9c:54:3d";
    }
    {
      hostname = "living-room-homepod";
      ipAddress = "10.65.0.107";
      mac = "58:d3:49:45:f7:87";
    }
    {
      hostname = "living-room-homepod2";
      ipAddress = "10.65.0.108";
      mac = "58:d3:49:18:dd:68";
    }
  ];

  # Allow DNS from selskap
  networking.firewall.interfaces."iot".allowedUDPPorts = [67 68];

  services.dnsmasq = {
    enable = true;

    # don't use it locally for dns
    resolveLocalQueries = lib.mkDefault false;
    settings = {
      interface = [
        config.my.lan
        # "iot0"
      ];
      # Only reserve the ports on the interfaces
      # served by dnsmasq and not wildcard.
      bind-interfaces = true;

      except-interface = [
        "virbr0"
      ];

      # disable dns
      port = 0;

      dhcp-range = [
        "interface:${config.my.lan},10.65.0.171,10.65.0.250,255.255.255.0,12h"
        "interface:iot,192.168.156.100,192.168.156.200,255.255.255.0,12h"
      ];

      dhcp-option = [
        # gateway
        "interface:${config.my.lan},option:router,10.65.0.1"
        "interface:iot,option:router,192.168.156.1"

        # dns server
        # "interface:${lan},option:dns-server,10.62.0.1"
        # "interface:${selskap},option:dns-server,192.168.200.1"
        "option:dns-server,10.65.0.1"
      ];

      dhcp-option-force = [
        "option:domain-search,ldn,fap.no,kradalby.no"
      ];

      # static leases
      dhcp-host = builtins.map (machine: "${machine.mac},${machine.hostname},${machine.ipAddress}") config.my.machines;
    };
  };
}
