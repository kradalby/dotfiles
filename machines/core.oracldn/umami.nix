{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "umami.kradalby.no";
  port = 63458;
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.externalVhost {
    inherit domain;
    proxyPass = "http://localhost:${toString port}";
  };
in
  lib.mkMerge [
    {
      users.users.umami = {
        home = "/var/lib/umami";
        createHome = true;
        group = "umami";
        isSystemUser = true;
        isNormalUser = false;
        description = "umami analytics";
      };

      users.groups.umami = {};

      virtualisation.oci-containers.containers.umami = {
        # NOTE: manual update required
        # https://github.com/umami-software/umami/pkgs/container/umami
        image = "ghcr.io/umami-software/umami:postgresql-v2.9.0";
        user = config.users.users.umami.uid;
        # workdir = "/home/podmanager";
        autoStart = true;
        ports = [
          "${toString port}:3000/tcp"
        ];
        environment = {
          DATABASE_URL = "postgresql://umami@172.17.0.1/umami";
        };
        environmentFiles = [];
        volumes = [];
      };
    }
    vhost
  ]
