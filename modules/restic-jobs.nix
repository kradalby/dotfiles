{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.restic.jobs;

  defaultPrune = [
    # Backups run hourly; without --keep-hourly every intra-day restore point
    # was pruned within the hour. Lock retry lives in the prune unit's
    # ExecStart (restic-jobs-linux.nix), not here.
    "--keep-hourly 24"
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
        description = "Name of the age secret containing the repository password.";
      };

      owner = mkOption {
        type = types.str;
        default = "root";
        description = "Owner of the password secret file.";
      };

      paths = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Filesystem paths passed to `restic backup`.";
      };

      repository = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Restic repository URL. Required unless `site` is set.";
      };

      site = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shortcut for homelab restic endpoints. When set, and `repository` is
          left null, the module generates
          `rest:http://restic-<site>.dalby.ts.net/<targetHost>`.
        '';
      };

      targetHost = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Hostname used when constructing repositories for `site` jobs. Defaults
          to this machine's FQDN.
        '';
      };

      pruneOpts = mkOption {
        type = types.listOf types.str;
        default = defaultPrune;
        description = "Options passed to `restic forget --prune`.";
      };

      initialize = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Auto-create the repository. Off by default: the init pre-start runs
          `restic snapshots || restic init`, which has no lock retry and fails
          the whole unit when it lands inside the weekly check. All repos
          already exist; set true only to bootstrap a brand-new one.
        '';
      };

      extraBackupArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments appended to `restic backup`.";
      };

      extraOptions = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Arguments passed via `restic --option`.";
      };

      dynamicFilesFrom = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Command invoked to generate a `--files-from` list.";
      };

      timerConfig = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Override the default systemd timer configuration on Linux.";
      };

      extraConfig = mkOption {
        type = types.attrs;
        default = { };
        description = "Additional attributes merged into `services.restic.backups.<name>`.";
      };

      check = {
        enable = mkOption {
          type = types.bool;
          default = pkgs.stdenv.isLinux;
          description = "Periodically verify the repository with `restic check`. Failures land the unit in `failed`, which the fleet-wide ServiceFailed alert pages on.";
        };

        args = mkOption {
          type = types.listOf types.str;
          # A percentage picks a RANDOM subset per run, so all packs get
          # verified over time; a fixed fraction (1/14) would re-read the same
          # packs forever.
          default = [ "--read-data-subset=7%" ];
          description = "Arguments to `restic check`. The default reads a random ~7% of pack data per run; set to [] for a metadata-only check (e.g. paid-egress remotes).";
        };

        interval = mkOption {
          type = types.str;
          default = "weekly";
          description = "systemd OnCalendar expression for the check timer.";
        };
      };
    };
  };

  # fqdn when a domain is set, else the bare hostname — unlike networking.fqdn,
  # which throws on a domainless host. Same value restic-jobs-linux.nix uses.
  defaultTargetHost = config.networking.fqdnOrHostName;

  buildJob =
    jobName: jobCfg:
    let
      targetHost = if jobCfg.targetHost != null then jobCfg.targetHost else defaultTargetHost;
      repository =
        if jobCfg.repository != null then
          jobCfg.repository
        else if
          jobCfg.site != null
        # http, not https: the restic-<site> VIP passes tcp:80/443 straight
        # through to a plain-HTTP rest-server — Tailscale VIP tcp:443 does not
        # TLS-terminate, so https dials into a bare HTTP server. The tailnet
        # already encrypts transit. http-only until upstream fixes it:
        #   https://github.com/tailscale/tailscale/issues/19724
        #   https://github.com/tailscale/tailscale/issues/18381
        # TODO(kradalby): revert to https once resolved.
        then
          "rest:http://restic-${jobCfg.site}.dalby.ts.net/${targetHost}"
        else
          null;

      # Linux-only: the Macs back up via rustic.
      linuxExtras = {
        timerConfig =
          if jobCfg.timerConfig != null then
            jobCfg.timerConfig
          else
            {
              OnCalendar = "hourly";
            };
      };

      backupConfig = {
        inherit repository;
        inherit (jobCfg)
          paths
          initialize
          extraOptions
          ;
        # No prune here: with pruneOpts set, the nixpkgs module runs
        # forget --prune after EVERY backup — 24 repacks/day per repo,
        # including paid Jottacloud egress. Pruning runs on its own weekly
        # unit instead (restic-jobs-linux.nix) using jobCfg.pruneOpts.
        pruneOpts = [ ];
        # `restic check` takes an exclusive lock, so once it stops failing
        # fast it will hold one for real. Backups have to wait it out too, or
        # the fix just moves the failure to the backup unit. 45m keeps a
        # waiting backup from running past the next hourly tick.
        extraBackupArgs = [ "--retry-lock=45m" ] ++ jobCfg.extraBackupArgs;
        passwordFile = config.age.secrets.${jobCfg.secret}.path;
      }
      // optionalAttrs (jobCfg.dynamicFilesFrom != null) {
        dynamicFilesFrom = jobCfg.dynamicFilesFrom;
      }
      // linuxExtras
      // jobCfg.extraConfig;
    in
    if jobCfg.enable then
      {
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
    else
      {
        assertions = [ ];
        secrets = { };
        backups = { };
      };

  jobResults = mapAttrsToList buildJob cfg;
  # The symlink guard and pushgateway success-push drop-ins live in
  # ./restic-jobs-linux.nix (Linux-only, where the systemd units run).
in
{
  options.services.restic.jobs = mkOption {
    type = types.attrsOf (types.submodule jobModule);
    default = { };
    description = ''
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
