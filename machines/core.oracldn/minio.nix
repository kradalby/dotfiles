{ pkgs, lib, config, ...}:
let
  domain = "minio.${config.networking.domain}";
in
{
  age.secrets.minio-oracldn = {
    file = ../../secrets/minio-oracldn.age;
  };

  services.minio = {
    enable = true;
    consoleAddress = "127.0.0.1:49005";
    rootCredentialsFile = config.age.secrets.minio-oracldn.path;
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyWebsockets = true;
      proxyPass = "http://${config.services.minio.listenAddress}";

      extraConfig = ''
        access_log /var/log/nginx/${domain}.access.log;
      '';
    };
  };
}
