{
  pkgs,
  config,
  lib,
  flakes,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  domain = "scrypted.${config.networking.domain}";
in
  lib.mkMerge [
    {
      virtualisation.oci-containers.containers.scrypted = {
        # NOTE: manual update required
        # https://hub.docker.com/r/koush/scrypted/tags
        image = "koush/scrypted:18-jammy-full.s6-v0.72.0";
        # user = config.users.users.stirling.uid;
        autoStart = true;
        # ports = [
        #   "${toString port}:8080/tcp"
        # ];

        environment = {
          SCRYPTED_DOCKER_AVAHI = "true";
        };
        ports = [
          "10443:10443/tcp"
        ];
        volumes = [
          "/var/lib/scrypted:/server/volume"
        ];
        extraOptions = [
          "--network=host"
        ];
      };
    }
    (nginx.internalVhost {
      inherit domain;
      proxyPass = "https://127.0.0.1:10443";
      locationExtraConfig = ''
        proxy_ssl_verify              off;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_upgrade;
        proxy_buffering off;
      '';
    })
  ]
