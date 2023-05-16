{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "umami.kradalby.no";
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  vhost = nginx.externalVhost {
    inherit domain;
    proxyPass = "http://localhost:${toString config.services.umami.port}";
  };
in
  lib.mkMerge [
    {
      services.umami = {
        enable = true;
      };
    }
    vhost
  ]
