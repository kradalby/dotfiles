{ pkgs, lib, config, ... }:
let
  domain = "login.kradalby.no";
in
{
  age.secrets.postgres-keycloak = {
    file = ../../secrets/postgres-keycloak.age;
    owner = "postgres";
  };

  services.keycloak = {
    enable = true;

    httpPort = "38089";
    bindAddress = "127.0.0.1";

    frontendUrl = "https://${domain}/auth";
    forceBackendUrlToFrontendUrl = true;

    database = {
      createLocally = true;
      type = "postgresql";
      useSSL = false;

      host = "localhost";
      port = config.services.postgresql.port;
      passwordFile = config.age.secrets.postgres-keycloak.path;
    };

    extraConfig = {
      "subsystem=undertow" = {
        "server=default-server" = {
          "http-listener=default" = {
            "proxy-address-forwarding" = true;
          };
          "https-listener=https" = {
            "proxy-address-forwarding" = true;
          };
        };
      };
    };

  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${config.services.keycloak.httpPort}";
      # proxyWebsockets = true;
      # extraConfig = ''
      #   proxy_set_header X-Forwarded-For $proxy_protocol_addr;
      #   proxy_set_header X-Forwarded-Proto $scheme;
      #   proxy_set_header Host $host;
      #   proxy_set_header X-Frame-Options "SAMEORIGIN";
      # '';
      # extraConfig = ''
      #   proxy_set_header Host $host;
      #   proxy_set_header X-Real-IP $remote_addr;
      #   proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #   proxy_set_header X-Forwarded-Proto $scheme;
      #   proxy_set_header Access-Control-Allow-Origin *;
      # '';
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };

}
