{
  pkgs,
  inputs,
  config,
  ...
}: let
  paseo = inputs.paseo.packages.${pkgs.stdenv.hostPlatform.system}.default;
  port = 6767;
  dataDir = "${config.home.homeDirectory}/.paseo";
in {
  home.packages = [paseo];

  systemd.user.services.paseo = {
    Unit = {
      Description = "Paseo - self-hosted daemon for AI coding agents";
      After = ["network.target"];
    };

    Service = {
      Type = "simple";
      ExecStart = "${paseo}/bin/paseo-server --no-relay";
      Restart = "on-failure";
      RestartSec = 5;
      KillSignal = "SIGTERM";
      TimeoutStopSec = 15;
      Environment = [
        "NODE_ENV=production"
        "PASEO_HOME=${dataDir}"
        "PASEO_LISTEN=0.0.0.0:${toString port}"
        "PASEO_HOSTNAMES=paseo-kradalby-llm.corp.ts.net"
      ];
    };

    Install.WantedBy = ["default.target"];
  };
}
