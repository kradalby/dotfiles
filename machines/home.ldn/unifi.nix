{
  pkgs,
  config,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};
  consul = import ../../common/funcs/consul.nix {inherit lib;};

  domain = "unifi.${config.networking.domain}";
in
  lib.mkMerge [
    {
      services.unifi = {
        unifiPackage = pkgs.unifi.overrideAttrs (attrs: {
          meta = attrs.meta // {license = lib.licenses.mit;};
        });
        enable = true;
        openFirewall = true;

        # initialJavaHeapSize = 1024;
        # maximumJavaHeapSize = 1536;
      };

      # TODO: Remove 8443 when nginx can correctly proxy
      networking.firewall.allowedTCPPorts = [8443 9130];

      # age.secrets.unifi-ldn-read-only = {
      #   file = ../../secrets/unifi-ldn-read-only.age;
      #   mode = "0400";
      #   owner = "unifi-poller";
      # };

      # services.unifi-poller = {
      #   enable = true;
      #
      #   unifi.defaults = {
      #     url = "https://127.0.0.1:8443";
      #     user = "read-only";
      #     pass = config.age.secrets.unifi-ldn-read-only.path;
      #
      #     verify_ssl = false;
      #   };
      #
      #   influxdb.disable = true;
      #
      #   prometheus = {
      #     http_listen = ":9130";
      #   };
      # };
      #
      # my.consulServices.unifi_exporter = consul.prometheusExporter "unifi" config.services.prometheus.exporters.unifi.port;
    }

    (nginx.internalVhost {
      inherit domain;
      proxyPass = "https://localhost:8443/";
      proxyWebsockets = true;
      locationExtraConfig = ''
        proxy_set_header Accept-Encoding "";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Front-End-Https on;
        proxy_redirect off;
      '';
    })
  ]
