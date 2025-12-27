{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.restic.jobs;

  defaultPrune = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
    "--keep-yearly 75"
  ];

  jobModule = { name, ... }: {
    options = {
      enable = mkEnableOption "restic job ${name}";

      secret = mkOption {
        type = types.str;
        description = mdDoc "Name of the age secret containing the repository password.";
      };

      owner = mkOption {
        type = types.str;
        default = "root";
        description = mdDoc "Owner of the password secret file.";
      };

      paths = mkOption {
        type = types.listOf types.str;
        default = [];
        description = mdDoc "Filesystem paths passed to `restic backup`.";
      };

      repository = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc "Restic repository URL. Required unless `site` is set.";
      };

      site = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc ''
          Shortcut for homelab restic endpoints. When set, and `repository` is
          left null, the module generates
          `rest:https://restic-<site>.dalby.ts.net/<targetHost>`.
        '';
      };

      targetHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc ''
          Hostname used when constructing repositories for `site` jobs. Defaults
          to this machine's FQDN.
        '';
      };

      pruneOpts = mkOption {
        type = types.listOf types.str;
        default = defaultPrune;
        description = mdDoc "Options passed to `restic forget --prune`.";
      };

      initialize = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc "Whether to auto-create the repository.";
      };

      extraBackupArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = mdDoc "Extra arguments appended to `restic backup`.";
      };

      extraOptions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = mdDoc "Arguments passed via `restic --option`.";
      };

      dynamicFilesFrom = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc "Command invoked to generate a `--files-from` list.";
      };

      logPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc "Override the log directory on Darwin.";
      };

      calendarInterval = mkOption {
        type = types.nullOr (types.attrsOf types.int);
        default = null;
        description = mdDoc "Override the default launchd calendar interval on Darwin.";
      };

      timerConfig = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = mdDoc "Override the default systemd timer configuration on Linux.";
      };

      extraConfig = mkOption {
        type = types.attrs;
        default = {};
        description = mdDoc "Additional attributes merged into `services.restic.backups.<name>`.";
      };
    };
  };

  defaultTargetHost =
    let
      fqdn = lib.attrByPath ["networking" "fqdn"] null config;
      hostName = lib.attrByPath ["networking" "hostName"] null config;
      domain = lib.attrByPath ["networking" "domain"] null config;
    in
      if fqdn != null && fqdn != ""
      then fqdn
      else if hostName != null && domain != null && domain != ""
      then "${hostName}.${domain}"
      else hostName or "localhost";

  buildJob = jobName: jobCfg:
    let
      targetHost = if jobCfg.targetHost != null then jobCfg.targetHost else defaultTargetHost;
      repository =
        if jobCfg.repository != null
        then jobCfg.repository
        else if jobCfg.site != null
        # TODO(kradalbyy): Change back to https when services supports terminating
        # and proxying http.
        then "rest:http://restic-${jobCfg.site}.dalby.ts.net/${targetHost}"
        else null;

      darwinExtras =
        if pkgs.stdenv.isDarwin
        then {
          logPath =
            if jobCfg.logPath != null
            then jobCfg.logPath
            else "/Users/kradalby/Library/Logs";
          calendarInterval =
            if jobCfg.calendarInterval != null
            then jobCfg.calendarInterval
            else {
              Minute = 30;
            };
        }
        else {};

      linuxExtras =
        if pkgs.stdenv.isLinux
        then {
          timerConfig =
            if jobCfg.timerConfig != null
            then jobCfg.timerConfig
            else {
              OnCalendar = "hourly";
            };
        }
        else {};

      backupConfig =
        {
          inherit repository;
          inherit (jobCfg) paths pruneOpts initialize extraBackupArgs extraOptions;
          passwordFile = config.age.secrets.${jobCfg.secret}.path;
        }
        // optionalAttrs (jobCfg.dynamicFilesFrom != null) {
          dynamicFilesFrom = jobCfg.dynamicFilesFrom;
        }
        // darwinExtras
        // linuxExtras
        // jobCfg.extraConfig;
    in
      if jobCfg.enable
      then {
        assertions = [
          {
            assertion = repository != null;
            message = "services.restic.jobs.${jobName} requires either `repository` or `site`.";
          }
        ];

        secrets.${jobCfg.secret} = {
          file = ../secrets + "/${jobCfg.secret}.age";
          owner = jobCfg.owner;
        };

        backups.${jobName} = backupConfig;
      }
      else {
        assertions = [];
        secrets = {};
        backups = {};
      };

  jobResults = mapAttrsToList buildJob cfg;
in {
  options.services.restic.jobs = mkOption {
    type = types.attrsOf (types.submodule jobModule);
    default = {};
    description = mdDoc ''
      Declarative restic backup jobs. Each entry provisions the password
      secret and creates `services.restic.backups.<name>` with sensible defaults.
    '';
  };

  config = {
    assertions = concatMap (result: result.assertions) jobResults;
    age.secrets = mkMerge (map (result: result.secrets) jobResults);
    services.restic.backups = mkMerge (map (result: result.backups) jobResults);
  };
}
