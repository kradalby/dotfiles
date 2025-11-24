{
  pkgs,
  lib,
  config,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  port = 56899;
in {
  services.restic.server = {
    enable = true;
    dataDir = "/storage/restic";
    prometheus = true;
    listenAddress = toString port;
    extraFlags = ["--no-auth"];
  };

  services.tailscale.services."svc:restic-core-terra" = {
    endpoints = {
      "tcp:80" = "http://127.0.0.1:${toString port}";
      "tcp:443" = "http://127.0.0.1:${toString port}";
    };
  };

  users.users.tailscale-restic-proxy = {
    isSystemUser = true;
    home = "/var/lib/tailscale-restic-proxy";
    description = "Tailscale Restic Proxy";
    createHome = true;
    shell = "/run/current-system/sw/bin/nologin";
    group = "tailscale-restic-proxy";
  };
  users.groups.tailscale-restic-proxy = {};

  systemd.services.tailscale-restic-proxy = {
    enable = true;
    description = "Tailscale Restic Proxy";
    wantedBy = ["multi-user.target"];
    after = ["restic-rest-server.service"];

    script = ''
        export TS_AUTHKEY=$(cat ${config.age.secrets.tailscale-preauthkey.path})
      ${pkgs.tailscale-restic-proxy}/bin/ts-restic-proxy \
        --ts-auth-key $TS_AUTHKEY \
        --restic-rest-server http://127.0.0.1:${toString port}/ \
        --hostname=restic-terra \
        --htpasswd-file ${config.users.users.tailscale-restic-proxy.home}/htpasswd
    '';

    serviceConfig = {
      User = "tailscale-restic-proxy";
      Group = "tailscale-restic-proxy";
      Restart = "always";
      RestartSec = "15";
      WorkingDirectory = config.users.users.tailscale-restic-proxy.home;
    };
  };

  my.consulServices.restic_server = consul.prometheusExporter "rest-server" port;
}
