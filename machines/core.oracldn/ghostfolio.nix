{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "folio.fap.no";
  port = 63457;
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.internalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString port}";
  };
in
  lib.mkMerge [
    {
      users.users.ghostfolio = {
        home = "/var/lib/ghostfolio";
        createHome = true;
        group = "ghostfolio";
        isSystemUser = true;
        isNormalUser = false;
        description = "ghostfolio PDF";
      };

      users.groups.ghostfolio = {};

      # services.redis.servers.ghostfolio = {
      #   enable = true;
      #
      #   user = config.users.users.ghostfolio.uid;
      #   requirePass = "not-that-important";
      # };

      virtualisation.oci-containers.containers.ghostfolio = {
        image = "ghostfolio/ghostfolio:1.305.0";
        user = config.users.users.ghostfolio.uid;
        # workdir = "/home/podmanager";
        autoStart = true;
        ports = [
          "3333:${toString port}/tcp"
        ];
        environment = {
          ACCESS_TOKEN_SALT = "bg#cnuVNbP9TqSKpPT&KD#w8m@$Y7&Yc";
          JWT_SECRET_KEY = "F5&VA8bsLSfcQHxB!izq3qfUvm^JysQJ";
          DATABASE_URL = "postgresql://ghostfolio@172.17.0.1/ghostfolio";
          NODE_ENV = "production";
          # REDIS_HOST = "redis";
          # REDIS_PASSWORD = config.services.redis.servers.ghostfolio.requirePass;
        };
        volumes = [
          "/run/postgresql:/run/postgresql"
          # "${config.services.redis.servers.ghostfolio.unixSocket}:/run/redis"
        ];
      };
    }
    vhost
  ]
