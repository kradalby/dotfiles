{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tailscale;

  # Generate JSON configuration matching Tailscale Services spec
  servicesJson = {
    version = "0.0.1";
    services = mapAttrs (name: svcCfg: {
      inherit (svcCfg) endpoints advertised;
    }) cfg.services;
  };

  configFile = pkgs.writeText "tailscale-services.json" (builtins.toJSON servicesJson);

in {
  options.services.tailscale.services = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        endpoints = mkOption {
          type = types.attrsOf types.str;
          description = lib.mdDoc ''
            Endpoint mappings for this service.

            Key format: "tcp:PORT" or "tcp:START-END"
            TODO: Update to support "http:PORT" and "https:PORT" when Tailscale Services exits beta

            Value format: "tcp://host:port" or "http://host:port" or "https://host:port"
          '';
          example = {
            "tcp:443" = "https://localhost:8443";
            "tcp:5432" = "tcp://localhost:5432";
          };
        };

        advertised = mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            Whether the service can accept new connections. Defaults to true.
          '';
        };
      };
    });
    default = {};
    description = lib.mdDoc ''
      Tailscale Services configuration.

      Service names should include the 'svc:' prefix as required by Tailscale.

      Services must be pre-defined in the Tailscale admin console at
      https://login.tailscale.com/admin/services
    '';
    example = literalExpression ''
      {
        "svc:prometheus" = {
          endpoints."tcp:443" = "http://localhost:9090";
        };
        "svc:postgres" = {
          endpoints."tcp:5432" = "tcp://localhost:5432";
        };
      }
    '';
  };

  config = mkIf (cfg.enable && cfg.services != {}) {
    systemd.services.tailscale-serve-config = {
      description = "Apply Tailscale Services configuration";

      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "tailscale-serve-config" ''
          # Wait until tailscaled is ready
          until ${pkgs.tailscale}/bin/tailscale status &>/dev/null; do
            sleep 1
          done

          # Apply Tailscale Services configuration
          ${pkgs.tailscale}/bin/tailscale serve set-config --all ${configFile}
        '';
      };

      restartTriggers = [ configFile ];
    };
  };
}
