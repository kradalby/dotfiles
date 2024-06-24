{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  consul = import ./funcs/consul.nix {inherit lib;};
  port = 54909;
  replicate = db: {
    inherit (db) path;
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
      {
        name = "tjoda";
        type = "s3";
        bucket = "databases";
        path = db.name;
        endpoint = "http://minio.tjoda.fap.no:9000";
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

  config = {
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

    my.consulServices.litestreamExporter = consul.prometheusExporter "litestream" port;
  };
}
