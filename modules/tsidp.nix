{
  config,
  lib,
  pkgs-unstable,
  ...
}
: let
  cfg = config.services.tsidp;
in {
  options = with lib; {
    services.tsidp = {
      enable = mkEnableOption "Enable tsidp";

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/tsidp";
        description = "tsidp state dir";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.tsidp = {
      enable = true;
      description = "Tailscale OpenID Connect service";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        TS_HOSTNAME = "idp";
        TS_USERSPACE = "false";
        TAILSCALE_USE_WIP_CODE = "1";
        TS_STATE_DIR = "${cfg.dataDir}";
      };

      serviceConfig = {
        Type = "simple";
        RestartSec = 5;
        Restart = "always";
        User = "root";
        ExecStart = "${pkgs-unstable.tailscale}/bin/tsidp";
      };
    };
  };
}
