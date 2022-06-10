{ pkgs, lib, config, ... }:
let
  databases = [
    "glauth"
    "nextcloud"
  ];

  backup = [
    "keycloak"
  ] ++ databases;
in
{
  services.postgresql = {
    enable = true;

    package = pkgs.postgresql_14;

    ensureUsers = builtins.map
      (database:
        {
          name = database;
          ensurePermissions = {
            "DATABASE ${database}" = "ALL PRIVILEGES";
          };
        }
      )
      databases;

    ensureDatabases = databases;
  };

  services.postgresqlBackup = {
    enable = true;

    databases = backup;
  };
}
