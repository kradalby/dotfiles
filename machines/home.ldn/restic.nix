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
    # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
    # targetHost is the opaque repo name on Jotta — house convention, nothing
    # host-identifying on the provider side.
    jotta =
      mkJob "jotta"
      // {
        targetHost = "bd1468c246bc9f509f8f423c32e86811";
        # Jotta egress is paid/slow: verify metadata only, monthly. The REST
        # repos get the read-data checks.
        check = {
          args = [];
          interval = "monthly";
        };
      };
  };
}
