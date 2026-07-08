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
    # litestream >= 0.5 allows one replica per database. Replicate
    # off-site to tjoda's minio (a local replica on the same host is no
    # DR) over its tailnet VIP service; reachable via the svc:minio-tjoda
    # grant. restic covers file-level off-site backup.
    replicas = [
      {
        name = "tjoda";
        type = "s3";
        bucket = "databases";
        path = db.name;
        endpoint = "http://minio-tjoda.dalby.ts.net:9000";
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
