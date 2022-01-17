{ config, lib, ... }:
let
  domain = "zigbee2mqtt.${config.networking.domain}";
in
{
  services.zigbee2mqtt = {
    enable = true;


    settings = {
      homeassistant = false;
      permit_join = false;

      frontend = {
        port = 48080;
        host = "0.0.0.0";
      };
      serial = {
        port = "/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0";
      };

      mqtt = {
        base_topic = "zigbee2mqtt";
        server = "mqtt://localhost";
        user = "zigbee2mqtt";
        password = "londonderry";
      };

      devices = {

        "0x00158d0005867f78" = {
          friendly_name = "bedroom-aqara";
        };
        "0x00158d00058a1f24" = {
          friendly_name = "bathroom-aqara";
        };
        "0x00158d00056bfcd7" = {
          friendly_name = "entrance-aqara";
        };
        "0x00158d0005889210" = {
          friendly_name = "living-room-aqara";
        };

        "0xec1bbdfffe9a2eaa" = {
          friendly_name = "entrance-switch";
        };
        "0xbc33acfffe76d2c3" = {
          friendly_name = "living-room-shelf-light";
        };
        "0xccccccfffebeb856" = {
          friendly_name = "entrance-light";
        };

        "0xec1bbdfffea3c9b3" = {
          friendly_name = "bedroom-switch";
        };
        "0xec1bbdfffeae279e" = {
          friendly_name = "bedroom-ceiling-light";
        };
        "0xec1bbdfffe269185" = {
          friendly_name = "bedroom-speaker-light";
        };

      };

      groups = {
        "1" = {
          friendly_name = "entrance";
          devices = [
            "living-room-shelf-light"
            "entrance-light"
          ];
        };
        "2" = {
          friendly_name = "bedroom";
          devices = [
            "bedroom-ceiling-light"
            "bedroom-speaker-light"
          ];
        };
      };
    };
  };
  systemd.services.zigbee2mqtt.onFailure = [ "notify-discord@%n.service" ];

  networking.firewall.allowedTCPPorts = [ config.services.zigbee2mqtt.settings.frontend.port ];

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.zigbee2mqtt.settings.frontend.port}";
      proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };

}
