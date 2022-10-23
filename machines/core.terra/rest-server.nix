{
  lib,
  config,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  domain = "restic.${config.networking.domain}";
  port = 56899;
in
  lib.mkMerge [
    {
      services.restic.server = {
        enable = true;
        dataDir = "/storage/restic";
        prometheus = true;
        listenAddress = "127.0.0.1:${toString port}";
        extraFlags = ["--no-auth"];
      };

      my.consulServices.restic_server = consul.prometheusExporter "rest-server" port;
    }

    (nginx.internalVhost {
      inherit domain;
      proxyPass = "http://127.0.0.1:${toString port}";
      tailscaleAuth = false;
    })
  ]
