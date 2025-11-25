{
  pkgs,
  config,
  lib,
  ...
}:
  lib.mkMerge [
    {
      # Controller upgrades unpack large archives into /tmp, so keep at least ~4GB around.
      boot.tmp.tmpfsSize = "4G";

      services.unifi = {
        unifiPackage = pkgs.unifi;
        mongodbPackage = pkgs.mongodb;

        enable = true;
        openFirewall = true;

        initialJavaHeapSize = 1024;
        maximumJavaHeapSize = 1536;
      };

      # TODO: Remove 8443 when nginx can correctly proxy
      networking.firewall.allowedTCPPorts = [8443 9130];

      # TODO: When Tailscale Services exits beta, use "http:80" and "https:443" instead of "tcp:"
      services.tailscale.services."svc:unifi-ldn" = {
        endpoints = {
          "tcp:80" = "https://localhost:8443";
          "tcp:443" = "https://localhost:8443";
        };
      };
    }
  ]
