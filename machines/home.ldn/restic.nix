{config, ...}: let
  paths = [
    "/etc/nixos"
    "/var/lib/zigbee2mqtt"
    # HomeKit pairing keys — losing these means re-pairing every accessory.
    "/var/lib/nefit-homekit"
    "/var/lib/tasmota-homekit"
    "/var/lib/z2m-homekit"
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
