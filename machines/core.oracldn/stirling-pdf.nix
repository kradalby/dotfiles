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
      services.tailscale.services."svc:pdf" = {
        endpoints."tcp:443" = "http://localhost:${toString port}";
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
        image = (import ../../metadata/versions.nix).stirling;
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
