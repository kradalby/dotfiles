{ config, ... }: let
  paths =
    [
      "/etc/nixos"
      "/var/lib/private/uptime-kuma"
      "/var/lib/step-ca"
      config.services.golink.dataDir
      config.services.postgresqlBackup.location
      config.services.minio.configDir
      config.services.grafana.dataDir
      # "/var/lib/kanidm/backup"
    ]
    ++ config.services.minio.dataDir;

  mkJob = site: {
    enable = true;
    inherit site paths;
    secret = "restic-core-oracldn-token";
  };
in {
  services.restic.jobs = {
    tjoda = mkJob "tjoda";
    # terra = mkJob "terra"; # disabled - terra is down
  };
}
