{ config, lib, ... }:
let
  consul = import ../../common/funcs/consul.nix { inherit lib; };

  port = 1883;
in
{
  imports = [ ../../modules/mqtt-exporter ];

  services.mosquitto = {
    enable = true;
    persistence = false;

    listeners = [
      {
        address = "0.0.0.0";
        port = port;
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

  systemd.services.mosquitto.onFailure = [ "notify-discord@%n.service" ];

  networking.firewall.allowedTCPPorts = [ port ];
  networking.firewall.allowedUDPPorts = [ port ];

  services.mqtt-exporter =
    let
      password = (builtins.elemAt config.services.mosquitto.listeners 0).users.exporter.password;
    in
    {
      enable = true;
      openFirewall = true;

      mqtt = {
        username = "exporter";
        password = password;
        keepalive = 30;
      };

      prometheus = {
        prefix = "sensor_";
        topicLabel = "sensor";
      };
    };

  systemd.services."mqtt-exporter".onFailure = [ "notify-discord@%n.service" ];

  my.consulServices.mqtt_exporter = consul.prometheusExporter "mqtt" config.services.mqtt-exporter.prometheus.port;
}
