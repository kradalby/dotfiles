{ config, lib, ... }:
{
  services.mosquitto = {
    enable = true;
    persistence = false;

    listeners = [
      {
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
        };
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 1883 ];
  networking.firewall.allowedUDPPorts = [ 1883 ];
}
