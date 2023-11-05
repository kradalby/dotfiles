{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "hvor.kradalby.no";
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.externalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString config.services.hvor.localhostPort}";
  };
in
  lib.mkMerge [
    {
      age.secrets.hvor-tskey = {
        file = ../../secrets/hvor-tskey.age;
        owner = config.services.hvor.user;
      };

      age.secrets.hvor-env = {
        file = ../../secrets/hvor-env.age;
        owner = config.services.hvor.user;
      };

      users.users.hvor = {
        home = config.services.hvor.dataDir;
        createHome = true;
        inherit (config.services.hvor) group;
        isSystemUser = true;
        isNormalUser = false;
        description = "hvor";
      };

      users.groups.hvor = {};

      services.hvor = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.hvor-tskey.path;
        environmentFile = config.age.secrets.hvor-env.path;
      };
    }
    vhost
  ]
