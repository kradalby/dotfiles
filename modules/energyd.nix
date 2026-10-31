{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.energyd;

  stateDir = "/var/lib/energyd";

  environment = {
    ENERGYD_DB_PATH = "${stateDir}/energyd.db";
    ENERGYD_LISTEN_ADDR = cfg.listenAddr;
    ENERGYD_METER = cfg.meter;
  };

  serviceConfig = {
    User = "energyd";
    Group = "energyd";
    EnvironmentFile = cfg.environmentFile;
    StateDirectory = "energyd";
    # setgid so litestream-created -wal/-shm inherit the group (litestream joins
    # it to replicate the db); group-writable via UMask below.
    StateDirectoryMode = "2770";
    UMask = "0007";

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
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    RestrictNamespaces = true;
    SystemCallFilter = [ "@system-service" ];
    SystemCallErrorNumber = "EPERM";
  };
in
{
  options.services.energyd = {
    enable = mkEnableOption "energyd, a ledger of what energy costs this home";

    package = mkOption {
      type = types.package;
      default = pkgs.energyd;
      description = "energyd package to use";
    };

    listenAddr = mkOption {
      type = types.str;
      default = "127.0.0.1:63463";
      description = "Address to expose /metrics and the JSON API on";
    };

    meter = mkOption {
      type = types.str;
      default = "power-p1-meter.ldn.fap.no";
      description = "HomeWizard P1 meter host";
    };

    environmentFile = mkOption {
      type = types.path;
      description = "Environment file with NEXTENERGY_USERNAME and NEXTENERGY_PASSWORD.";
    };
  };

  config = mkIf cfg.enable {
    users.users.energyd = {
      isSystemUser = true;
      group = "energyd";
    };
    users.groups.energyd = { };

    systemd.services.energyd = {
      description = "energyd energy cost ledger";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      inherit environment;

      serviceConfig = serviceConfig // {
        ExecStart = getExe cfg.package;
        Restart = "always";
        RestartSec = "30s";
      };
    };

    # Clears a login block after the credentials were fixed; restart energyd next.
    systemd.services.energyd-unblock = {
      description = "energyd clear NextEnergy login block";
      inherit environment;

      serviceConfig = serviceConfig // {
        Type = "oneshot";
        ExecStart = "${getExe cfg.package} unblock";
      };
    };

    # Run by hand once with `systemctl start energyd-backfill`. It is resumable
    # by missing days and stops at the first failure against the account, so it
    # must never restart on its own.
    systemd.services.energyd-backfill = {
      description = "energyd one-time history backfill from NextEnergy";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      inherit environment;

      serviceConfig = serviceConfig // {
        Type = "oneshot";
        ExecStart = "${getExe cfg.package} backfill";
      };
    };
  };
}
