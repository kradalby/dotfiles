{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  replicate = db: {
    inherit (db) path;
    replicas = [
      {
        type = "s3";
        bucket = "databases";
        path = db.name;
        endpoint = "minio.oracldn.fap.no";
        region = "us-east-1";
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

  config = {
    age.secrets.litestream = {
      file = ../secrets/litestream.age;
    };

    services.litestream = {
      enable = true;
      environmentFile = config.age.secrets.litestream.path;
      settings = {
        dbs = builtins.map replicate config.my.litestream.databases;
      };
    };
  };
}
