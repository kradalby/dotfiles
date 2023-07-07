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
      age.secrets.hugin-tskey = {
        file = ../../secrets/hugin-tskey.age;
        owner = "storage";
      };

      age.secrets.hugin-basicauth = {
        file = ../../secrets/hugin-basicauth.age;
        owner = "nginx";
      };

      services.hugin = {
        enable = true;
        tailscaleKeyPath = config.age.secrets.hugin-tskey.path;

        verbose = true;

        user = "storage";
        group = "storage";

        album = "/fast/hugin/album";
      };
    }
    vhost
  ]
