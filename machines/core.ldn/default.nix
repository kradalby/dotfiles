{ config, flakes, pkgs, lib, ... }:
{
  imports = [
    ../../common

    ../../common/acme.nix
    ../../common/nginx.nix
    ../../common/consul-server.nix
    ../../common/ddns.nix

    ./hardware-configuration.nix
    ./wireguard.nix
    ./tailscale.nix
  ];

  my.wan = "wan";
  my.lan = "eth0";

  environment.systemPackages = with pkgs; [
  ];

  boot.kernel.sysctl = {
    # if you use ipv4, this is all you need
    "net.ipv4.conf.all.forwarding" = true;

    # If you want to use it for ipv6
    "net.ipv6.conf.all.forwarding" = true;

    # source: https://github.com/mdlayher/homelab/blob/master/nixos/routnerr-2/configuration.nix#L52
    # By default, not automatically configure any IPv6 addresses.
    "net.ipv6.conf.all.accept_ra" = 0;
    "net.ipv6.conf.all.autoconf" = 0;
    "net.ipv6.conf.all.use_tempaddr" = 0;

    # On WAN, allow IPv6 autoconfiguration and tempory address use.
    "net.ipv6.conf.${config.my.wan}.accept_ra" = 2;
    "net.ipv6.conf.${config.my.wan}.autoconf" = 1;
  };

  networking = {
    hostName = "core";
    domain = "ldn.fap.no";
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    # defaultGateway = "129.241.210.1";
    # defaultGateway6 = "2001:700:300:2000::1";
    # dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce true;
    useNetworkd = false;

    vlans = {
      ${config.my.wan} = {
        interface = config.my.lan;
        id = 3;
      };

      iot = {
        interface = config.my.lan;
        id = 5;
      };
    };

    # bridges = {
    #   lan.interfaces = [ "eth0" "wlan0" ];
    # };

    interfaces = {
      ${config.my.wan} = {
        useDHCP = true;
      };

      ${config.my.lan} = {
        # It looks like Community Fiber has whitelisted this 
        # Mac address somehow, so keep it around incase we 
        # need a new machine.
        macAddress = "dc:a6:32:08:d3:e8";

        useDHCP = false;
        ipv4.addresses = [
          { address = "10.65.0.1"; prefixLength = 24; }
        ];
      };

      iot = {
        useDHCP = false;
        ipv4.addresses = [
          { address = "192.168.156.1"; prefixLength = 24; }
        ];
      };

    };

    nat = {
      enable = true;
      externalInterface = config.my.wan;
      internalIPs = [ "10.0.0.0/8" "192.168.156.0/24" ];
      internalInterfaces = [ config.my.lan "iot" ];
      forwardPorts = [
        { sourcePort = 64322; destination = "10.65.0.1:22"; proto = "tcp"; }
        { sourcePort = 500; destination = "10.65.0.1:51820"; proto = "udp"; }
        { sourcePort = 4500; destination = "10.65.0.1:51820"; proto = "udp"; }
      ];
    };
  };

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

  services.coredns = {
    enable = true;
    config =
      let
        domain = "ldn";
      in
      ''
        . {
          cache 3600 {
            success 8192
            denial 4096
          }
          prometheus :9153
          forward . tls://1.1.1.1 tls://1.0.0.1 tls://2606:4700:4700::1111 tls://2606:4700:4700::1001 {
            tls_servername tls.cloudflare-dns.com
            health_check 5s
          }
        }

        consul {
          forward . 127.0.0.1:8600 {
            health_check 5s
          }
        }

        # Internal zone.
        ${domain} {
          hosts {
            ${lib.concatMapStrings (host: ''
                ${host.ipAddress} ${host.hostName}.${domain}
              '') config.services.dhcpd4.machines
            }
          }
        }
      '';
  };

  systemd.services.coredns.onFailure = [ "notify-discord@%n.service" ];

  # networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [ 53 9153 ];
  # networking.firewall.interfaces."${config.my.lan}".allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces.eth0.allowedTCPPorts = [ 53 9153 ];
  networking.firewall.interfaces.eth0.allowedUDPPorts = [ 53 ];

  my.consulServices.coredns_exporter = {
    name = "coredns-exporter";
    tags = [ "coredns_exporter" "prometheus" ];
    port = 9153;
    check = {
      name = "coredns health check";
      http = "http://127.0.0.1:9153/metrics";
      interval = "60s";
      timeout = "1s";
    };
  };

  boot.cleanTmpDir = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11";
}
