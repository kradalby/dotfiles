{
  config,
  pkgs,
  lib,
  system,
  ...
}: let
  domain = "uptime.kradalby.no";
in {
  services.uptime-kuma = {
    enable = true;
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:3001";
      proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
