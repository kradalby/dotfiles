{
  pkgs,
  lib,
  config,
  ...
}: let
  nginx = import ./funcs/nginx.nix {inherit config lib;};

  domain = "minio.${config.networking.domain}";

  vhost = nginx.internalVhost {
    inherit domain;
    proxyPass = "http://${config.services.minio.consoleAddress}";
    tailscaleAuth = false;
  };
in
  lib.mkMerge [
    {
      age.secrets.minio-oracldn = {
        file = ../secrets/minio-oracldn.age;
      };

      services.minio = {
        enable = true;
        consoleAddress = "127.0.0.1:49005";
        rootCredentialsFile = config.age.secrets.minio-oracldn.path;
      };
    }
    vhost
  ]
