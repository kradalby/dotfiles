{
  config,
  pkgs,
  lib,
  ...
}: let
  domain = "desk.kradalby.no";
in {
  imports = [../../modules/rustdesk-server.nix];

  users.users.rustdesk-server = {
    home = "/var/lib/rustdesk-server";
    createHome = true;
    group = "rustdesk-server";
    isSystemUser = true;
    isNormalUser = false;
    description = "rustdesk-server";
  };

  users.groups.rustdesk-server = {};

  services."rustdesk-server" = {
    enable = true;
    openFirewall = true;

    inherit domain;
  };

  security.acme.certs."${domain}" = {
    inherit domain;
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:21117";
      proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
