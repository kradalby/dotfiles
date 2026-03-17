{
  pkgs,
  lib,
  config,
  ...
}: {
  options = {
    my.postgres = {
      databases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };

      extraBackups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
    };
  };

  config = {
    services.postgresql = {
      enable = true;

      package = pkgs.postgresql_14;

      enableTCPIP = true;

      ensureUsers =
        builtins.map
        (
          database: {
            name = database;
            ensureDBOwnership = true;
          }
        )
        config.my.postgres.databases;

      ensureDatabases = config.my.postgres.databases;
    };

    services.postgresqlBackup = {
      enable = true;

      databases = config.my.postgres.databases ++ config.my.postgres.extraBackups;
    };

    services.prometheus.exporters.postgres = {
      enable = true;
      runAsLocalSuperUser = true;
    };

    networking.firewall.interfaces."${config.my.lan}".allowedTCPPorts = [
      config.services.prometheus.exporters.postgres.port
    ];
  };
}
