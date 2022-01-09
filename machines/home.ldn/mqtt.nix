{ config, lib, ... }:
let
  port = 1883;
in
{
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
        };
      }
    ];
  };

  systemd.services.mosquitto.onFailure = [ "notify-email@%n.service" ];

  networking.firewall.allowedTCPPorts = [ port ];
  networking.firewall.allowedUDPPorts = [ port ];
}
