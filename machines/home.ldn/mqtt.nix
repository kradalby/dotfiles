{
  config,
  lib,
  ...
}: let
  port = 1883;
in {
  services.mosquitto = {
    enable = true;
    persistence = false;

    listeners = [
      {
        inherit port;
        address = "0.0.0.0";
        users = {
          zigbee2mqtt = {
            acl = [
              "readwrite zigbee2mqtt/#"
            ];
            password = "londonderry";
          };

          tasmota = {
            acl = [
              "readwrite #"
            ];
            password = "pluggyplugg";
          };

          homebridge = {
            acl = [
              "readwrite #"
            ];
            password = "birdbirdbirdistheword";
          };

          kradalby = {
            acl = [
              "readwrite #"
            ];
            password = "kradalby";
          };

          exporter = {
            acl = [
              "read #"
            ];
            password = "prometheus";
          };
        };
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [port];
  networking.firewall.allowedUDPPorts = [port];

  # zigbee2mqtt publishes to z2m-homekit's embedded broker (:51833, localhost,
  # no auth), NOT to mosquitto — live-verified 2026-07: mosquitto carries zero
  # traffic. Scraping mosquitto here meant the mqtt job was up==1 on an empty
  # broker. Tasmota energy data comes via the tasmota-exporter HTTP probes,
  # not MQTT.
  services.mqtt-exporter = {
    enable = true;
    openFirewall = true;

    mqtt = {
      port = config.services.z2m-homekit.ports.mqtt;
      keepalive = 30;
    };

    prometheus = {
      prefix = "sensor_";
      topicLabel = "sensor";
    };
  };
}
