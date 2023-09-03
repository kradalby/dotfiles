{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "pdf.fap.no";
  port = 68456;
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.internalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString port}";
  };
in
  lib.mkMerge [
    {
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
        image = "frooodle/s-pdf:0.13.1";
        user = config.users.users.stirling.uid;
        autoStart = true;
        ports = [
          "8080:${toString port}/tcp"
        ];
        environment = {};
        volumes = [
        ];
      };
    }
    vhost
  ]
