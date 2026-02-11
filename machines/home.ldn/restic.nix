{ config, ... }: let
  paths = [
    "/etc/nixos"
    "/var/lib/zigbee2mqtt"
    "/var/lib/homebridge"
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-home-ldn-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
  };
}
