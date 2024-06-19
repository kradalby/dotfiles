{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "pdf.fap.no";
  port = 63456;
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.internalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString port}";
  };
in
  lib.mkMerge [
    {
      services.tailscale-proxies.stirling-pdf = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

        hostname = "pdf";
        backendPort = port;
      };

      users.users.stirling = {
        home = "/var/lib/stirling";
        createHome = true;
        group = "stirling";
        isSystemUser = true;
        isNormalUser = false;
        description = "Stirling PDF";
      };

      users.groups.stirling = {};

      virtualisation.oci-containers.containers.stirling = {
        # NOTE: manual update required
        # https://hub.docker.com/r/frooodle/s-pdf/tags
        image = "frooodle/s-pdf:0.26.1";
        user = config.users.users.stirling.uid;
        autoStart = true;
        ports = [
          "${toString port}:8080/tcp"
        ];
        environment = {};
        volumes = [
        ];
      };
    }
    vhost
  ]
