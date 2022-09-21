{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.glauth-ui;
in {
  options.services.glauth-ui = {
    enable = mkEnableOption "Glauth UI for Glauth LDAP server";

    package = mkOption {
      type = types.package;
      description = ''
        Glauth UI package to use
      '';
      default = pkgs.glauth-ui;
      defaultText = literalExpression "python with overridden dependencies";
    };

    port = mkOption {
      type = types.port;
      default = 5000;
      description = "Port to listen to";
    };

    user = mkOption {
      type = types.str;
      default = "glauth";
      description = "User account under which Glauth UI runs.";
    };

    group = mkOption {
      type = types.str;
      default = "glauth";
      description = "Group account under which Glauth UI runs.";
    };

    mail = {
      server = mkOption {
        type = types.str;
        default = "localhost";
        description = "SMTP server to send mail";
      };

      port = mkOption {
        type = types.port;
        default = 25;
        description = "SMTP server port to send mail";
      };

      admin = mkOption {
        type = types.str;
        default = "admin@localhost";
        description = "Admin email";
      };
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/glauth";
      description = "Path to data dir, for config.cfg";
    };

    databaseUrl = mkOption {
      type = types.str;
      default = "postgresql://glauth@localhost:5432/glauth";
      description = "Database url";
    };

    cookieSecret = mkOption {
      type = types.str;
      default = "";
      description = "";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.glauth-ui = {
      enable = true;
      script = ''
        ${cfg.package}/bin/gunicorn -b :${toString cfg.port} --access-logfile - --error-logfile - ldap:app
      '';
      wantedBy = ["multi-user.target" "docker-glauth.service"];
      after = ["network-online.target"];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "15";
        WorkingDirectory = cfg.dataDir;
      };
      path = [cfg.packages];
      environment = {
        PYTHONPATH = "${pythonWithPackages}";
        SECRET_KEY = cfg.cookieSecret;
        MAIL_SERVER = cfg.mail.server;
        MAIL_PORT = "${toString cfg.mail.port}";
        MAIL_USE_TLS = "0";
        MAIL_ADMIN = cfg.mail.admin;
        DATABASE_URL = cfg.databaseUrl;
        GLAUTH_CFG_PATH = "${cfg.dataDir}/config.cfg";
      };

      preStart = ''
        ${cfg.package}/bin/flask db upgrade
        ${cfg.package}/bin/flask createdbdata
      '';
    };
  };
}
