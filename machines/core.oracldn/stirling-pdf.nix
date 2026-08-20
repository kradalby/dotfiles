{
  config,
  pkgs,
  lib,
  ...
}:
let
  port = 63456;
in
lib.mkMerge [
  {
    services.tailscale.services.pdf = {
      endpoints = {
        "tcp:80" = "http://localhost:${toString port}";
        # tcp:443 has no TLS termination — Tailscale VIP bug (tailscale/tailscale#19724, #18381); consumers use http. TODO(kradalby): revert when fixed.
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

    users.groups.stirling = { };

    virtualisation.oci-containers.containers.stirling = {
      image = (import ../../metadata/versions.nix).stirling;
      user = config.users.users.stirling.uid;
      autoStart = true;
      # Bind loopback only: reached via the `pdf` tailscale VIP -> localhost. A
      # bare <port>:8080 binds 0.0.0.0 and docker's DNAT rule bypasses the host
      # firewall, exposing it on this public Oracle VM's WAN leg.
      ports = [
        "127.0.0.1:${toString port}:8080/tcp"
      ];
      environment = { };
      volumes = [
      ];
    };
  }
]
