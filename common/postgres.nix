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

      ensureUsers =
        builtins.map
        (
          database: {
            name = database;
            ensurePermissions = {
              "DATABASE ${database}" = "ALL PRIVILEGES";
            };
          }
        )
        config.my.postgres.databases;

      ensureDatabases = config.my.postgres.databases;
    };

    services.postgresqlBackup = {
      enable = true;

      databases = config.my.postgres.databases ++ config.my.postgres.extraBackups;
    };
  };
}
