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
      age.secrets.ghostfolio-env = {
        file = ../../secrets/ghostfolio-env.age;
        owner = "ghostfolio";
      };

      users.users.ghostfolio = {
        home = "/var/lib/ghostfolio";
        createHome = true;
        group = "ghostfolio";
        isSystemUser = true;
        isNormalUser = false;
        description = "ghostfolio PDF";
      };

      users.groups.ghostfolio = {};

      services.redis.servers.ghostfolio = {
        enable = true;

        bind = "172.17.0.1";
        port = 6379;

        user = "ghostfolio";
        requirePass = "not-that-important";
      };

      virtualisation.oci-containers.containers.ghostfolio = {
        image = "ghostfolio/ghostfolio:1.305.0";
        user = config.users.users.ghostfolio.uid;
        # workdir = "/home/podmanager";
        autoStart = true;
        ports = [
          "${toString port}:3333/tcp"
        ];
        environment = {
          DATABASE_URL = "postgresql://ghostfolio@172.17.0.1/ghostfolio";
          NODE_ENV = "production";
          REDIS_HOST = "172.17.0.1";
          REDIS_PORT = toString config.services.redis.servers.ghostfolio.port;
          REDIS_PASSWORD = config.services.redis.servers.ghostfolio.requirePass;
        };
        environmentFiles = [
          config.age.secrets.ghostfolio-env.path
        ];
        volumes = [
          "/run/postgresql:/run/postgresql"
          # "${config.services.redis.servers.ghostfolio.unixSocket}:/run/redis"
        ];
      };
    }
    vhost
  ]
