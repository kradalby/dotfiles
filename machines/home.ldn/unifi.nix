{
  pkgs,
  config,
  lib,
  flakes,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  domain = "unifi.${config.networking.domain}";
in
  {
    disabledModules = ["services/networking/unifi.nix"];

    imports = [
      "${flakes.nixpkgs-unifi}/nixos/modules/services/networking/unifi.nix"
    ];
  }
  // lib.mkMerge [
    {
      services.unifi = {
        unifiPackage = pkgs.unifi.unifi.overrideAttrs (attrs: {
          meta = attrs.meta // {license = lib.licenses.mit;};
        });

        # jrePackage = pkgs.jdk17_headless.overrideAttrs {
        #   swingSupport = false; # don't need swing things
        #   guiSupport = false; # don't need GUI things
        # };
        #
        mongodbPackage = pkgs.mongodb-4_4.overrideAttrs {
          jsEngine = "none"; # can't cross compile mozjs
          allocator = "system"; # can't cross compile gperftools
        };

        enable = true;
        openFirewall = true;

        # initialJavaHeapSize = 1024;
        # maximumJavaHeapSize = 1536;
      };

      # TODO: Remove 8443 when nginx can correctly proxy
      networking.firewall.allowedTCPPorts = [8443 9130];

      # age.secrets.unifi-tjoda-read-only = {
      #   file = ../../secrets/unifi-tjoda-read-only.age;
      #   mode = "0400";
      #   owner = "unifi-poller";
      # };

      # services.unifi-poller = {
      #   enable = true;
      #
      #   unifi.defaults = {
      #     url = "https://127.0.0.1:8443";
      #     user = "read-only";
      #     pass = config.age.secrets.unifi-tjoda-read-only.path;
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

      # my.consulServices.unifi_exporter = consul.prometheusExporter "unifi" config.services.prometheus.exporters.unifi.port;
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
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Front-End-Https on;
        proxy_redirect off;
      '';
    })
  ]
