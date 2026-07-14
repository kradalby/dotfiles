{ config, ... }:
let
  paths = [
    "/etc/nixos"
    # uptime-kuma runs without DynamicUser; the /var/lib/private path was a
    # stale symlink target that backed up nothing.
    "/var/lib/uptime-kuma"
    # headscale's sqlite is otherwise only replicated via litestream; keep a
    # second, independent copy in restic.
    "/var/lib/headscale"
    config.services.golink.dataDir
    config.services.postgresqlBackup.location
    config.services.grafana.dataDir
  ];

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-core-oracldn-token";
  };
in
{
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    ldn = mkJob "ldn";
    # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
    # targetHost is the opaque repo name on Jotta — house convention, nothing
    # host-identifying on the provider side.
    jotta = mkJob "jotta" // {
      targetHost = "f553137cb49962eeb9f01cb958dfcf95";
      # Jotta egress is paid/slow: verify metadata only, monthly. The REST
      # repos get the read-data checks.
      check = {
        args = [ ];
        interval = "monthly";
      };
    };
  };
}
