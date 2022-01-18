{ config, ... }: {
  services.dhcpd4 = {
    enable = true;
    interfaces = [ config.my.lan "iot" ];
    extraConfig = ''
      option domain-name-servers 10.65.0.1;
      option subnet-mask 255.255.255.0;

      subnet 10.65.0.0 netmask 255.255.255.0 {
        option broadcast-address 10.65.0.255;
        option routers 10.65.0.1;
        interface ${config.my.lan};
        range 10.65.0.171 10.65.0.250;
      }

      subnet 192.168.156.0 netmask 255.255.255.0 {
        option broadcast-address 192.168.156.255;
        option routers 192.168.156.1;
        interface iot;
        range 192.168.156.100 192.168.156.200;
      }
    '';
    machines = [
      {
        hostName = "core";
        ipAddress = "10.65.0.1";
        ethernetAddress = "dc:a6:32:08:d3:e8";
      }
      {
        hostName = "home";
        ipAddress = "10.65.0.25";
        ethernetAddress = "dc:a6:32:a8:e8:f9";
      }
      {
        hostName = "kramacbook";
        ipAddress = "10.65.0.50";
        ethernetAddress = "b8:e8:56:3e:8f:da";
      }
      {
        hostName = "danielle-macbookpro";
        ipAddress = "10.65.0.51";
        ethernetAddress = "c8:e0:eb:16:7a:d9";
      }
      {
        hostName = "danielle-iphone";
        ipAddress = "10.65.0.52";
        ethernetAddress = "9a:4a:7f:aa:97:13";
      }
      {
        hostName = "gr-laptop";
        ipAddress = "10.65.0.53";
        ethernetAddress = "c8:34:8e:51:8b:43";
      }
      {
        hostName = "kradell";
        ipAddress = "10.65.0.54";
        ethernetAddress = "9c:b6:d0:da:bd:dd";
      }

      # Network
      {
        hostName = "skap-switch";
        ipAddress = "10.65.0.70";
        ethernetAddress = "e0:63:da:54:fc:fb";
      }
      {
        hostName = "tv-switch";
        ipAddress = "10.65.0.71";
        ethernetAddress = "f4:92:bf:a3:6a:23";
      }
      {
        hostName = "stue-ap";
        ipAddress = "10.65.0.72";
        ethernetAddress = "e0:63:da:25:cc:1e";
      }


      # IoT
      {
        hostName = "vacuum";
        ipAddress = "10.65.0.80";
        ethernetAddress = "78:11:dc:5f:f6:05";
      }
      {
        hostName = "bedroom-desk-light";
        ipAddress = "10.65.0.82";
        ethernetAddress = "a4:cf:12:c3:87:21";

      }
      {
        hostName = "living-room-fairy-light";
        ipAddress = "10.65.0.83";
        ethernetAddress = "2c:f4:32:6b:b3:57";
      }
      {
        hostName = "kitchen-fairy-light";
        ipAddress = "10.65.0.84";
        ethernetAddress = "a4:cf:12:c3:94:99";
      }
      {
        hostName = "bedroom-nook-light";
        ipAddress = "10.65.0.85";
        ethernetAddress = "50:02:91:5e:a5:90";
      }

      # Media
      {
        hostName = "sonos-boost";
        ipAddress = "10.65.0.101";
        ethernetAddress = "b8:e9:37:0b:5a:7a";
      }
      {
        hostName = "apple-tv";
        ipAddress = "10.65.0.102";
        ethernetAddress = "90:dd:5d:9b:46:49";
      }
      {
        hostName = "philips-tv";
        ipAddress = "10.65.0.103";
        ethernetAddress = "70:af:24:b8:4e:7b";
      }
      {
        hostName = "sonos-1";
        ipAddress = "10.65.0.104";
        ethernetAddress = "34:7e:5c:f0:22:30";
      }
      {
        hostName = "sonos-2";
        ipAddress = "10.65.0.105";
        ethernetAddress = "78:28:ca:d1:3c:88";
      }
      {
        hostName = "counter";
        ipAddress = "10.65.0.106";
        ethernetAddress = "e0:2b:96:9c:54:3d";
      }
      {
        hostName = "bedroom-airport";
        ipAddress = "10.65.0.107";
        ethernetAddress = "ac:7f:3e:ed:b4:10";
      }
      {
        hostName = "living-room-airport";
        ipAddress = "10.65.0.108";
        ethernetAddress = "00:f7:6f:d3:ac:e3";
      }
    ];
  };

  systemd.services.dhcpd4.onFailure = [ "notify-discord@%n.service" ];
}
