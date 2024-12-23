{
  pkgs,
  config,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  domain = "scrypted.${config.networking.domain}";
in
  lib.mkMerge [
    {
      networking.firewall.allowedTCPPorts = [48463];
      virtualisation.oci-containers.containers.scrypted = {
        image = (import ../../metadata/versions.nix).scrypted;
        autoStart = true;

        environment = {
          SCRYPTED_DOCKER_AVAHI = "false";
          HOSTNAME = "scrypted";
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
