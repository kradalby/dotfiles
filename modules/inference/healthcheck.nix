{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.inference;
  metricsDir = "/var/lib/prometheus-node-exporter-textfile";
  probe = pkgs.writeShellApplication {
    name = "inference-healthcheck";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      metrics=$(mktemp ${metricsDir}/inference.prom.XXXXXX)
      response=$(mktemp)
      trap 'rm -f "$metrics" "$response"' EXIT
      ${lib.concatMapStringsSep "\n" (
        model:
        let
          labels = "{service=${builtins.toJSON cfg.serviceName},model=${builtins.toJSON model}}";
          request = builtins.toJSON {
            inherit model;
            prompt = "Reply with OK.";
            stream = false;
            think = false;
            options = {
              num_predict = 8;
              num_ctx = cfg.contextLength;
            };
          };
        in
        ''
          success=0
          elapsed=0
          if elapsed=$(curl --fail --silent --show-error \
            --connect-timeout 3 --max-time ${toString cfg.healthCheck.timeout} \
            --output "$response" --write-out '%{time_total}' \
            --json ${lib.escapeShellArg request} \
            http://127.0.0.1:${toString cfg.port}/api/generate) \
            && jq -e '.done == true and .eval_count > 0 and (.response | length) > 0' "$response" >/dev/null; then
            success=1
          fi
          {
            printf 'llm_inference_probe_success%s %s\n' ${lib.escapeShellArg labels} "$success"
            printf 'llm_inference_probe_duration_seconds%s %s\n' ${lib.escapeShellArg labels} "''${elapsed:-0}"
            printf 'llm_inference_probe_timestamp_seconds%s %s\n' ${lib.escapeShellArg labels} "$(date +%s)"
          } >> "$metrics"
        ''
      ) cfg.models}
      chmod 0644 "$metrics"
      mv -f "$metrics" ${metricsDir}/inference.prom
    '';
  };
in
{
  options.services.inference.healthCheck = {
    enable = lib.mkEnableOption "periodic per-model inference probes" // {
      default = true;
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "Time between inference probes; each probe can swap the resident model.";
    };
    timeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 180;
      description = "Request timeout in seconds, including cold model loading and queue time.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.healthCheck.enable) {
    assertions = [
      {
        assertion =
          config.services.prometheus.exporters.node.enable
          && lib.elem "textfile" config.services.prometheus.exporters.node.enabledCollectors
          && lib.elem "--collector.textfile.directory=${metricsDir}" config.services.prometheus.exporters.node.extraFlags;
        message = "inference: health checks require the fleet node-exporter textfile collector.";
      }
    ];

    systemd.services.inference-healthcheck = {
      description = "Probe each local inference model and publish node-exporter metrics";
      requires = [ "ollama.service" ];
      after = [ "ollama.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe probe;
        TimeoutStartSec = toString (cfg.healthCheck.timeout * builtins.length cfg.models + 30);
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        ReadWritePaths = [ metricsDir ];
      };
    };
    systemd.timers.inference-healthcheck = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15m";
        OnUnitActiveSec = cfg.healthCheck.interval;
        RandomizedDelaySec = "2m";
      };
    };
  };
}
