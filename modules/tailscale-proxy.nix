{
  config,
  pkgs,
  lib,
  ...
} @ args:
with lib; let
  cfg = config.services.tailscale-proxies;
  username = "tailscale-proxy";
  baseDataDir = "/var/lib/${username}";
in {
  options.services.tailscale-proxies = mkOption {
    default = {};
    type = with types;
      attrsOf (submodule {
        options = {
          enable = mkEnableOption "Enable tailscale-proxy";

          package = mkOption {
            type = types.package;
            description = ''
              Package to use
            '';
            default = pkgs.unstable.tailscale-tools;
          };

          hostname = mkOption {
            type = types.str;
            default = "";
            description = "Hostname to use, presented via MagicDNS";
          };

          loginServer = mkOption {
            type = types.str;
            default = "";
            description = "Tailscale Control server to connect to";
          };

          backendPort = mkOption {
            type = types.port;
            description = "Port to proxy onto the tailscale network";
          };

          tailscaleKeyPath = mkOption {
            type = types.path;
          };
        };
      });
    description = lib.mdDoc ''
      Multiple tailscale-proxies
    '';
  };

  config = {
    users.users.tailscale-proxy = {
      home = baseDataDir;
      createHome = true;
      group = username;
      isSystemUser = false;
      isNormalUser = true;
      description = username;
    };

    users.groups.tailscale-proxy = {};

    systemd.services = flip mapAttrs' cfg (
      subSvcName: svcConfig: let
        svcName = "${username}-${subSvcName}";
        dataDir = "${baseDataDir}/${subSvcName}";
      in
        nameValuePair svcName
        {
          inherit (svcConfig) enable;
          wantedBy = ["multi-user.target"];
          after = ["network.target"];
          restartTriggers = [svcConfig.package];
          script = ''
            mkdir -p ${dataDir}
            export TS_AUTHKEY=`cat ${svcConfig.tailscaleKeyPath}`
            ${svcConfig.package}/bin/proxy-to-grafana \
              --hostname=${svcConfig.hostname} \
              --backend-addr=localhost:${toString svcConfig.backendPort} \
              --state-dir=${dataDir} \
              --login-server=${svcConfig.loginServer} \
              --use-https=false
          '';
          serviceConfig = {
            User = username;
            Group = username;
            Restart = "always";
            RestartSec = "15";
            WorkingDirectory = baseDataDir;
          };
        }
    );
  };
}
