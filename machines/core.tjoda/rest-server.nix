{ lib, config, ... }:
let
  consul = import ../../common/funcs/consul.nix { inherit lib; };

  domain = "restic.${config.networking.domain}";
  port = 56899;
in
{
  services.restic.server = {
    enable = true;
    dataDir = "/storage/restic";
    prometheus = true;
    listenAddress = "127.0.0.1:${toString port}";
    extraFlags = [ "--no-auth" ];
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };

  my.consulServices.restic_server = consul.prometheusExporter "rest-server" port;
}
