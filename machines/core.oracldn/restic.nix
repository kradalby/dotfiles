{
  pkgs,
  config,
  lib,
  ...
}: let
  restic = import ../../common/funcs/restic.nix {inherit config lib pkgs;};
  helpers = import ../../common/funcs/helpers.nix {inherit pkgs lib;};

  paths =
    [
      "/etc/nixos"
      "/var/lib/private/uptime-kuma"
      "/var/lib/step-ca"
      config.services.golink.dataDir
      config.services.postgresqlBackup.location
      config.services.minio.configDir
      config.services.grafana.dataDir
      "/var/lib/kanidm/backup"
    ]
    ++ config.services.minio.dataDir;

  cfg = site: {
    secret = "restic-core-oracldn-token";
    inherit site;
    inherit paths;
  };
in
  lib.mkMerge [
    (restic.backupJob (cfg "tjoda"))
    (restic.backupJob (cfg "terra"))
  ]
