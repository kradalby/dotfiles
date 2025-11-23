{
  pkgs,
  config,
  lib,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  domain = "unifi.${config.networking.domain}";
in
  lib.mkMerge [
    {
      # Controller upgrades unpack large archives into /tmp, so keep at least ~4GB around.
      boot.tmp.tmpfsSize = "4G";

      services.unifi = {
        unifiPackage = pkgs.unifi;
        mongodbPackage = pkgs.mongodb;

        enable = true;
        openFirewall = true;

        initialJavaHeapSize = 1024;
        maximumJavaHeapSize = 1536;
      };

      # TODO: Remove 8443 when nginx can correctly proxy
      networking.firewall.allowedTCPPorts = [8443 9130];

      # TODO: When Tailscale Services exits beta, use "http:80" and "https:443" instead of "tcp:"
      services.tailscale.services."svc:unifi-ldn" = {
        endpoints = {
          "tcp:80" = "https://localhost:8443";
          "tcp:443" = "https://localhost:8443";
        };
      };
    }
    (nginx.internalVhost {
      inherit domain;

      proxyPass = "https://localhost:8443/";
      proxyWebsockets = true;
      locationExtraConfig = ''
        # https://community.ui.com/questions/Controller-NGINX-Proxy-login-error/49b64c94-3925-4163-ba33-c1d6206d1fa1#answer/4c9f52e0-d9f1-40a2-9ff7-94223bddd75f
        proxy_set_header Referer "";

        proxy_set_header Accept-Encoding "";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Front-End-Https on;
        proxy_redirect off;


        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        # proxy_http_version 1.1;
        proxy_set_header Connection "upgrade";
      '';
    })
  ]
