{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.umami;
in {
  options.services.umami = {
    enable = mkEnableOption "Enable Umami";

    package = mkOption {
      type = types.package;
      description = ''
        umami package to use
      '';
      default = pkgs.umami;
    };

    port = mkOption {
      type = types.port;
      default = 43000;
      description = "Port to listen to";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/umami";
      description = "Path to data dir, for config.cfg";
    };

    databaseUrl = mkOption {
      type = types.str;
      default = "postgresql://umami@localhost:5432/umami";
      description = "Database url";
    };

    cookieSecret = mkOption {
      type = types.str;
      default = "";
      description = "";
    };
  };

  config = mkIf cfg.enable {
    users.users.umami = {
      home = cfg.dataDir;
      createHome = true;
      group = "umami";
      isSystemUser = false;
      isNormalUser = true;
      description = "user for umami web service";
    };
    users.groups.umami = {};

    systemd.services.umami = {
      enable = true;
      script = ''
        ${pkgs.yarn}/bin/yarn --cwd ${cfg.package}/libexec/umami/deps/umami start-docker
      '';
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      serviceConfig = {
        User = "umami";
        Group = "umami";
        Restart = "always";
        RestartSec = "15";
        WorkingDirectory = cfg.dataDir;
      };
      path = [pkgs.yarn];
      environment = {
        PORT = toString cfg.port;
        DATABASE_URL = cfg.databaseUrl;
        # NODE_PATH = "${cfg.package}/libexec/umami/node_modules/";
      };
    };
  };
}
