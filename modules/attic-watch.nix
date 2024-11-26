{
  config,
  pkgs,
  lib,
  ...
}: {
  options.services.attic-watch = {
    enable = lib.mkEnableOption "Enable attic watch service";
    target = lib.mkOption {
      type = lib.types.str;
      default = "system";
      description = "the target cache destination to push to";
    };
  };

  config = lib.mkIf config.services.attic-watch.enable {
    systemd.services.attic-watch = {
      description = "Attic Watch Store Service";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.attic-client}/bin/attic watch-store ${config.services.attic-watch.target}";
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
