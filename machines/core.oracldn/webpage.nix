{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "kradalby.no";
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.externalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString config.services.krapage.localhostPort}";
  };
in
  lib.mkMerge [
    {
      age.secrets.krapage-tskey = {
        file = ../../secrets/krapage-tskey.age;
        owner = config.services.krapage.user;
      };

      age.secrets.krapage-env = {
        file = ../../secrets/krapage-env.age;
        owner = config.services.krapage.user;
      };

      users.users.krapage = {
        home = config.services.krapage.dataDir;
        createHome = true;
        inherit (config.services.krapage) group;
        isSystemUser = true;
        isNormalUser = false;
        description = "krapage";
      };

      users.groups.krapage = {};

      services.krapage = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.krapage-tskey.path;
        environmentFile = config.age.secrets.krapage-env.path;
      };
    }
    vhost
  ]
