{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.cook-server;
in {
  options.services.cook-server = {
    enable = mkEnableOption "Cook recipe server";

    package = mkOption {
      type = types.package;
      default = pkgs.cook-cli;
      description = "Package to use for the cook CLI";
    };

    port = mkOption {
      type = types.port;
      default = 9080;
      description = "Port to listen on";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/cook-server";
      description = "Directory for recipes";
    };

    user = mkOption {
      type = types.str;
      default = "cook-server";
      description = "User account under which cook-server runs.";
    };

    group = mkOption {
      type = types.str;
      default = "cook-server";
      description = "Group account under which cook-server runs.";
    };
  };

  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = {};

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.cook-server = {
      description = "Cook recipe server";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      script = ''
        exec ${cfg.package}/bin/cook server --port ${toString cfg.port} --host
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = "15";
      };
    };
  };
}
