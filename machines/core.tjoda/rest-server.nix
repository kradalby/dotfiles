{
  pkgs,
  lib,
  config,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  port = 56899;
in {
  services.restic.server = {
    enable = true;
    dataDir = "/storage/restic";
    prometheus = true;
    listenAddress = toString port;
    extraFlags = ["--no-auth"];
  };

  services.tailscale.services."svc:restic-core-tjoda" = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString port}";
      "tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };

  my.consulServices.restic_server = consul.prometheusExporter "rest-server" port;
}
