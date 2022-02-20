{ config, pkgs, lib, tf, ... }: with lib; let
  keystore-pass = "randomsupersecret_prodigal2earphone6snowplow_booting-flashback7daringly2";

  domain = "login.kradalby.no";
in
{
  age.secrets.postgres-keycloak = {
    file = ../../secrets/postgres-keycloak.age;
    owner = "postgres";
  };

  services.keycloak = {
    enable = true;
    package = (pkgs.keycloak.override {
      jre = pkgs.openjdk11;
    });
    bindAddress = "127.0.0.1";
    httpPort = "38089";
    httpsPort = "38445";
    initialAdminPassword = "initial_1define2algorithm3reappear6mower1triangle0juiciness0";
    forceBackendUrlToFrontendUrl = true;
    frontendUrl = "https://${domain}/auth";
    database.passwordFile = config.age.secrets.postgres-keycloak.path;
    extraConfig = {
      "subsystem=undertow" = {
        "server=default-server" = {
          "http-listener=default" = {
            "proxy-address-forwarding" = true;
          };
        };
      };
      "subsystem=keycloak-server" = {
        "spi=truststore" = {
          "provider=file" = {
            enabled = true;
            properties.password = keystore-pass;
            properties.file = "/var/lib/acme/${domain}/trust-store.jks";
            properties.hostname-verification-policy = "WILDCARD";
            properties.disabled = false;
          };
        };
      };
    };
  };


  # network.extraCerts.domain-login-kradalby-no = "auth.${config.network.dns.domain}";
  users.groups.domain-login-kradalby-no.members = [ "nginx" "openldap" "keycloak" ];
  security.acme.certs.${domain} = {
    domain = domain;
    group = "domain-login-kradalby-no";
    postRun = ''
      ${pkgs.adoptopenjdk-jre-bin}/bin/keytool -delete -alias ${domain} -keypass ${keystore-pass} -storepass ${keystore-pass} -keystore ./trust-store.jks
      ${pkgs.adoptopenjdk-jre-bin}/bin/keytool -import -alias ${domain} -noprompt -keystore trust-store.jks -keypass ${keystore-pass} -storepass ${keystore-pass} -file cert.pem
      chown acme:domain-login-kradalby-no ./trust-store.jks
    '';
  };

  # users.groups.keycloak = { };
  # users.users.keycloak = {
  #   isSystemUser = true;
  #   group = "keycloak";
  # };
  #
  # kw.secrets.variables.keycloak-postgres = {
  #   path = "services/keycloak";
  #   field = "postgres";
  # };
  #
  # secrets.files.keycloak-postgres-file = {
  #   text = "${tf.variables.keycloak-postgres.ref}";
  #   owner = "postgres";
  #   group = "keycloak";
  # };

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

  # deploy.tf.dns.records.services_keycloak = {
  #   inherit (config.network.dns) zone;
  #   domain = "auth";
  #   cname = { inherit (config.network.addresses.public) target; };
  # };
}
