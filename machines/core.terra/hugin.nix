{
  lib,
  config,
  ...
}: let
  domain = "hugin.kradalby.no";
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.externalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString config.services.hugin.localhostPort}";
    basicAuthFile = config.age.secrets.hugin-basicauth.path;
  };
in
  lib.mkMerge [
    {
      age.secrets.hugin-basicauth = {
        file = ../../secrets/hugin-basicauth.age;
        owner = "nginx";
      };

      age.secrets.hugin-tokens = {
        file = ../../secrets/hugin-tokens.age;
        owner = "storage";
      };

      services.hugin = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

        verbose = true;

        user = "storage";
        group = "storage";

        album = "/fast/hugin/album";

        environmentFile = config.age.secrets.hugin-tokens.path;
      };
    }
    vhost
  ]
