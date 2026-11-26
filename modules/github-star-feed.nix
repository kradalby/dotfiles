{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.github-star-feed;
in
{
  options.services.github-star-feed = {
    enable = mkEnableOption "GitHub private feed filtered to star and follow events";

    package = mkOption {
      type = types.package;
      default = pkgs.github-star-feed;
      description = "github-star-feed package to use";
    };

    listenAddr = mkOption {
      type = types.str;
      default = "localhost:63469";
      description = "Address serving /feed and /metrics";
    };

    environmentFile = mkOption {
      type = types.path;
      description = "Environment file with GITHUB_STAR_FEED_URL, the private feed URL including its token.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.github-star-feed = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment.GITHUB_STAR_FEED_LISTEN_ADDR = cfg.listenAddr;

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
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        SystemCallFilter = [ "@system-service" ];
        SystemCallErrorNumber = "EPERM";
      };
    };
  };
}
