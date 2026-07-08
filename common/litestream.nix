{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  port = 54909;
  replicate = db: {
    inherit (db) path;
    # litestream >= 0.5 allows one replica per database. Keep the local
    # minio (reachable); off-site coverage comes from restic. tjoda's
    # minio (10.62.0.1:9000) was unreachable when this was cut down.
    replicas = [
      {
        name = "oracldn";
        type = "s3";
        bucket = "databases";
        path = db.name;
        endpoint = "http://minio.oracldn.fap.no:9000";
        region = "us-east-1";
        validation-interval = "24h";
      }
    ];
  };
in {
  options = {
    my.litestream.databases = lib.mkOption {
      type = types.listOf (types.attrsOf types.str);
      default = [];
    };
  };

  config = lib.mkIf (config.my.litestream.databases != []) {
    age.secrets.litestream = {
      file = ../secrets/litestream.age;
    };

    services.litestream = {
      enable = true;
      environmentFile = config.age.secrets.litestream.path;
      settings = {
        addr = ":${toString port}";
        dbs = builtins.map replicate config.my.litestream.databases;
      };
    };
  };
}
