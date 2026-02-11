{
  pkgs,
  lib,
  config,
  ...
}: let
  port = 56899;
in {
  services.restic.server = {
    enable = true;
    dataDir = "/storage/restic";
    prometheus = true;
    listenAddress = "127.0.0.1:${toString port}";
    extraFlags = ["--no-auth"];
  };

  services.tailscale.services."svc:restic-ldn" = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString port}";
      "tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };
}
