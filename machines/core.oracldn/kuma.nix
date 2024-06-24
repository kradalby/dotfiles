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

  users.users.uptime-kuma = {
    name = "uptime-kuma";
    isSystemUser = true;
    home = "/var/lib/uptime-kuma";
    homeMode = "770";
    createHome = true;
    group = "uptime-kuma";
  };
  users.groups.uptime-kuma = {};

  systemd.services.uptime-kuma.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = config.users.users.uptime-kuma.name;
    Group = config.users.users.uptime-kuma.name;
    WorkingDirectory = config.users.users.uptime-kuma.home;
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
