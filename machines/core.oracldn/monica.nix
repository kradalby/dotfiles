{
  pkgs,
  lib,
  config,
  ...
}: {
  # age.secrets.monica-app-key = {
  #   file = ../../secrets/monica-app-key.age;
  #   owner = config.services.monica.user;
  # };

  services.monica = {
    enable = false;

    appKeyFile = config.age.secrets.monica-app-key.path;
    appURL = "http://monica.dalby.ts.net";

    database.createLocally = false;

    config = {
      DB_DATABASE = lib.mkForce "${config.services.monica.dataDir}/db.sqlite";
      DB_HOST = lib.mkForce "";
      DB_PORT = lib.mkForce "";
      DB_USERNAME = lib.mkForce "";
    };
  };
}
