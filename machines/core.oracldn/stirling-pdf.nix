{
  config,
  pkgs,
  lib,
  ...
}: let
  port = 63456;
in
  lib.mkMerge [
    {
      services.tailscale.services.pdf = {
        endpoints = {
          "tcp:80" = "http://localhost:${toString port}";
          # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(tailscale-vip-tls): revert when fixed.
          "tcp:443" = "http://localhost:${toString port}";
        };
      };

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
        image = (import ../../metadata/versions.nix).stirling;
        user = config.users.users.stirling.uid;
        autoStart = true;
        ports = [
          "${toString port}:8080/tcp"
        ];
        environment = {};
        volumes = [
        ];
      };
    }
  ]
