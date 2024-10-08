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
    allowCors = false;
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
        image = (import ../../metadata/versions.nix).umami;
        user = config.users.users.umami.uid;
        # workdir = "/home/podmanager";
        autoStart = true;
        ports = [
          "${toString port}:3000/tcp"
        ];
        environment = {
          DATABASE_URL = "postgresql://umami@172.17.0.1/umami";
          DISABLE_TELEMETRY = "1";
          DISABLE_UPDATES = "1";
        };
        environmentFiles = [];
        volumes = [];
      };
    }
    vhost
  ]
