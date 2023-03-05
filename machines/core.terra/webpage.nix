{ pkgs
, lib
, config
, ...
}:
let
  domain = "kradalby.no";
  nginx = import ../../common/funcs/nginx.nix { inherit config lib; };

  vhost = nginx.externalVhost {
    inherit domain;
    proxyPass = "http://127.0.0.1:${toString config.services.kradalby.port}";
  };
in
lib.mkMerge [
  {
    services.kradalby = {
      enable = true;
    };
  }
  vhost
]
