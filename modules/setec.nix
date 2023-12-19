{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.setec;
in {
  options.services.setec = {
    enable = mkEnableOption "Tailscale setec secret store";

    package = mkOption {
      type = types.package;
      description = ''
        Package to use
      '';
      default = pkgs.setec;
    };

    hostname = mkOption {
      type = types.str;
      default = "secrets";
      description = "Hostname the setec secret store will use in your tailnet";
    };

    kmsKeyName = mkOption {
      type = types.str;
      default = "";
      description = "AWS KMS name, on the form arn:....";
    };

    user = mkOption {
      type = types.str;
      default = "setec";
      description = "User account under which setec runs.";
    };

    group = mkOption {
      type = types.str;
      default = "setec";
      description = "Group account under which setec runs.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/setec";
      description = "Path to data dir";
    };

    tailscaleKeyPath = mkOption {
      type = types.path;
    };

    # verbose = mkOption {
    #   type = types.bool;
    #   default = false;
    # };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/var/lib/secrets/setec";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.setec = {
      enable = true;
      description = "Tailscale setec secret store";
      script = ''
        export TS_AUTHKEY=$(cat ${cfg.tailscaleKeyPath})
        ${cfg.package}/bin/setec server --hostname=${cfg.hostname} --kms-key-name=${cfg.kmsKeyName} --state-dir ${cfg.dataDir}
      '';
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];

      serviceConfig = {
        # DynamicUser = true;
        User = "config.services.${cfg.user}.user";
        Group = "config.services.${cfg.group}.group";
        Restart = "always";
        RestartSec = "15";
        EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        WorkingDirectory = cfg.dataDir;
      };

      path = [cfg.package];
    };
  };
}
