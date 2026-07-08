{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.oci-usage-exporter;
in {
  options.services.oci-usage-exporter = {
    enable = mkEnableOption "Prometheus exporter for Oracle Cloud usage/cost";

    package = mkOption {
      type = types.package;
      default = pkgs.oci-usage-exporter;
      description = "oci-usage-exporter package to use";
    };

    listenAddr = mkOption {
      type = types.str;
      default = "localhost:63461";
      description = "Address to expose /metrics on";
    };

    interval = mkOption {
      type = types.str;
      default = "1h";
      description = "How often to query the OCI Usage API (Go duration)";
    };

    environmentFile = mkOption {
      type = types.path;
      description = ''
        Environment file with OCI_USAGE_ACCOUNTS and per-account
        OCI_USAGE_<NAME>_{TENANCY_OCID,USER_OCID,FINGERPRINT,REGION,PRIVATE_KEY_B64}.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.oci-usage-exporter = {
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      environment = {
        OCI_USAGE_LISTEN_ADDR = cfg.listenAddr;
        OCI_USAGE_INTERVAL = cfg.interval;
      };

      serviceConfig = {
        ExecStart = getExe cfg.package;
        EnvironmentFile = cfg.environmentFile;
        DynamicUser = true;
        Restart = "always";
        RestartSec = "15";

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6"];
      };
    };
  };
}
