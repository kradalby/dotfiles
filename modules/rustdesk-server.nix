{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.services.rustdesk-server;
in {
  options.services.rustdesk-server = {
    enable = mkEnableOption "Rustdesk server";

    package = mkOption {
      type = types.package;
      description = ''
        Rustdesk package to use
      '';
      default = pkgs.rustdesk-server;
      defaultText = literalExpression "python with overridden dependencies";
    };

    user = mkOption {
      type = types.str;
      default = "rustdesk-server";
      description = "User account under which rustdesk-server runs.";
    };

    group = mkOption {
      type = types.str;
      default = "rustdesk-server";
      description = "Group account under which rustdesk-server runs.";
    };

    domain = mkOption {
      type = types.str;
      default = "";
      description = "Public facing domain where rustdesk-server will run";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/rustdesk-server";
      description = "Path to data dir, for config.cfg";
    };

    pubKeyFile = mkOption {
      type = types.path;
      description = "ed25519 public key, generated if empty";
    };

    privKeyFile = mkOption {
      type = types.path;
      description = "ed25519 private key, generated if empty";
    };

    openFirewall = mkEnableOption "opening of the metric in the firewall";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [21115 21116 21117 21118 21119];
    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [21116];

    systemd.services.rustdesk-server-hbbs = {
      enable = true;
      script = ''
        ${cfg.package}/bin/hbbs -r ${cfg.domain}:21117
      '';
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "15";
        WorkingDirectory = "${cfg.dataDir}";
      };
      path = [cfg.package];
      environment = {};
    };

    systemd.services.rustdesk-server-hbbr = {
      enable = true;
      script = ''
        ${cfg.package}/bin/hbbr
      '';
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "15";
        WorkingDirectory = "${cfg.dataDir}";
      };
      path = [cfg.package];
      environment = {
        ENCRYPTED_ONLY = "1";
      };

      preStart = ''
        ln -sf ${cfg.pubKeyFile} ${cfg.dataDir}/id_ed25519.pub
        ln -sf ${cfg.privKeyFile} ${cfg.dataDir}/id_ed25519
      '';
    };
  };
}
