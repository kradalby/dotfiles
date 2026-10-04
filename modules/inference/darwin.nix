{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.inference;
  localHost = "127.0.0.1:${toString cfg.port}";
  modelLoader = pkgs.writeShellScript "inference-models" ''
    set -euo pipefail
    export OLLAMA_HOST=${lib.escapeShellArg localHost}
    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      ${lib.escapeShellArg cfg.executable} list >/dev/null 2>&1 && break
      sleep 2
    done
    ${lib.concatMapStringsSep "\n" (
      model: "${lib.escapeShellArg cfg.executable} pull ${lib.escapeShellArg model}"
    ) cfg.models}
  '';
  proxyConfig = pkgs.writeText "inference.Caddyfile" ''
    {
      admin off
      auto_https off
    }
    :${toString cfg.proxyPort} {
      bind 127.0.0.1
      reverse_proxy ${localHost} {
        header_up Host {upstream_hostport}
      }
    }
  '';
in
{
  imports = [ inputs.tailscale.darwinModules.default ];

  options.services.inference = {
    executable = lib.mkOption {
      type = lib.types.str;
      default = "/Applications/Ollama.app/Contents/Resources/ollama";
      description = "MLX-capable Ollama app executable; nixpkgs Ollama currently disables MLX.";
    };
    tailscaleInstance = lib.mkOption {
      type = lib.types.str;
      default = "kradalby";
      description = "Existing tagged userspace Tailscale instance advertising this service.";
    };
    proxyPort = lib.mkOption {
      type = lib.types.port;
      default = 11435;
      description = "Loopback Host-rewrite proxy port, following the existing Mac serving pattern.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.port != cfg.proxyPort;
        message = "inference: runner and Host-rewrite proxy need different ports.";
      }
      {
        assertion = config.services.tailscales.${cfg.tailscaleInstance}.enable or false;
        message = "inference: enable the selected tagged Tailscale instance before advertising a VIP.";
      }
    ];

    services.tailscales.${cfg.tailscaleInstance}.services.${cfg.serviceName}.endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString cfg.proxyPort}";
    };

    launchd.user.agents = {
      inference.serviceConfig = {
        ProgramArguments = [
          cfg.executable
          "serve"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Logs/inference.log";
        StandardErrorPath = "${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Logs/inference.log";
        EnvironmentVariables = cfg.environment // {
          OLLAMA_HOST = localHost;
        };
      };
      inference-models.serviceConfig = {
        ProgramArguments = [ "${modelLoader}" ];
        RunAtLoad = true;
        # A failed download retries; a successful bootstrap stays stopped.
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 30;
        StandardOutPath = "${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Logs/inference-models.log";
        StandardErrorPath = "${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Logs/inference-models.log";
      };
      inference-proxy.serviceConfig = {
        ProgramArguments = [
          "${pkgs.caddy}/bin/caddy"
          "run"
          "--adapter"
          "caddyfile"
          "--config"
          "${proxyConfig}"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Logs/inference-proxy.log";
        StandardErrorPath = "${
          config.users.users.${config.system.primaryUser}.home
        }/Library/Logs/inference-proxy.log";
      };
    };
  };
}
