{
  pkgs,
  lib,
  config,
  ...
}: let
  domain = "files.kradalby.no";
in {
  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      root = "/fast/files";
      extraConfig = ''
        autoindex on;
      '';
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
