{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.inference;
  firewall = config.networking.firewall;
  opensPort =
    rules:
    lib.elem cfg.port rules.allowedTCPPorts
    || lib.any (range: range.from <= cfg.port && cfg.port <= range.to) rules.allowedTCPPortRanges;
in
{
  imports = [ ./healthcheck.nix ];

  options.services.inference.package = lib.mkPackageOption pkgs "ollama-${cfg.acceleration}" { };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "inference: enable Tailscale before advertising a VIP.";
      }
      {
        # A wildcard listener makes Ollama accept the VIP Host header. The
        # firewall must keep the unauthenticated management API off the LAN.
        assertion =
          firewall.enable
          && lib.all (interface: interface == "lo") firewall.trustedInterfaces
          && !opensPort firewall
          && lib.all (rules: !opensPort rules) (lib.attrValues firewall.interfaces)
          && config.services.ollama.host == "0.0.0.0"
          && config.services.ollama.port == cfg.port
          && !config.services.ollama.openFirewall;
        message = "inference: the wildcard Ollama listener requires an enabled firewall, no trusted non-loopback interfaces, and a closed backend port on every interface.";
      }
    ];

    services.ollama = {
      enable = true;
      inherit (cfg) package port;
      host = "0.0.0.0";
      openFirewall = false;
      loadModels = cfg.models;
      environmentVariables = cfg.environment;
    };

    systemd.services.ollama.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
      KillMode = "mixed";
      TimeoutStopSec = "60s";
    };

    services.tailscale = {
      enable = true;
      services.${cfg.serviceName}.endpoints = {
        # VIP tcp:443 does not terminate TLS with the pinned Tailscale version.
        "tcp:80" = "http://127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
