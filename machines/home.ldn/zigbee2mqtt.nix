{
  config,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};
  domain = "zigbee2mqtt.${config.networking.domain}";
in
  lib.mkMerge [
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

          availability = {
            active = {
              # Time after which an active device will be marked as offline in
              # minutes (default = 10 minutes)
              timeout = 10;
            };
            passive = {
              # Time after which a passive device will be marked as offline in
              # minutes (default = 1500 minutes aka 25 hours)
              timeout = 1500;
            };
          };

          mqtt = {
            base_topic = "zigbee2mqtt";
            server = "mqtt://127.0.0.1";
            user = "zigbee2mqtt";
            password = "londonderry";
          };

          devices = {
            "0x00158d0005867f78" = {
              friendly_name = "kitchen-aqara";
            };
            "0x00158d00058a1f24" = {
              friendly_name = "bathroom-aqara";
            };
            "0x00158d00056bfcd7" = {
              friendly_name = "office-aqara";
            };
            "0x00158d0005889210" = {
              friendly_name = "living-room-aqara";
            };

            "0xec1bbdfffe9a2eaa" = {
              friendly_name = "living-switch";
            };
            "0xccccccfffebeb856" = {
              friendly_name = "living-window-light";
            };
            "0xec1bbdfffeae279e" = {
              friendly_name = "living-inner-light";
            };

            # "0xbc33acfffe76d2c3" = {
            #   friendly_name = "living-room-shelf-light";
            # };

            # "0xec1bbdfffea3c9b3" = {
            #   friendly_name = "bedroom-switch";
            # };
            "0xec1bbdfffe269185" = {
              friendly_name = "living-room-speaker-light";
            };

            "0x00158d0007ed50e9" = {
              friendly_name = "office-motion";
            };
          };

          groups = {
            "1" = {
              friendly_name = "living-room";
              devices = [
                "living-window-light"
                "living-inner-light"
              ];
            };
            # "2" = {
            #   friendly_name = "bedroom";
            #   devices = [
            #     "bedroom-ceiling-light"
            #     "bedroom-speaker-light"
            #   ];
            # };
          };
        };
      };

      networking.firewall.allowedTCPPorts = [config.services.zigbee2mqtt.settings.frontend.port];
    }

    (nginx.internalVhost {
      inherit domain;
      proxyPass = "http://127.0.0.1:${toString config.services.zigbee2mqtt.settings.frontend.port}";
    })
  ]
