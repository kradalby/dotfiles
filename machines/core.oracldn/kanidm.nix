{
  config,
  pkgs,
  ...
}: let
  domain = "auth.kradalby.no";
  certDir = config.security.acme.certs."${domain}".directory;
in {
  age.secrets = {
    kanidm-admin-password = {
      file = ../../secrets/kanidm-admin-password.age;
      owner = "kanidm";
      group = "kanidm";
    };

    kanidm-idm-admin-password = {
      file = ../../secrets/kanidm-idm-admin-password.age;
      owner = "kanidm";
      group = "kanidm";
    };

    kanidm-headscale-oidc-secret = {
      file = ../../secrets/headscale-oidc-secret.age;
      owner = "kanidm";
      group = "kanidm";
    };
  };

  services.kanidm = {
    package = pkgs.kanidm.withSecretProvisioning;
    enableServer = true;
    serverSettings = {
      inherit domain;
      origin = "https://${domain}";

      tls_key = "${certDir}/key.pem";
      tls_chain = "${certDir}/full.pem";

      bindaddress = "127.0.0.1:3013";
      ldapbindaddress = "127.0.0.1:3636";
      trust_x_forward_for = true;
      db_fs_type = "xfs";

      online_backup = {
        path = "/var/lib/kanidm/backup";
        schedule = "0 0 * * *";
      };
    };

    provision = {
      enable = true;
      adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
      idmAdminPasswordFile = config.age.secrets.kanidm-idm-admin-password.path;

      persons = {
        # Generate a credentials reset link:
        # nix-shell -p kanidm
        # kanidm person credential create-reset-token <USERNAME> --name idm_admin
        kradalby = {
          displayName = "Kristoffer Dalby";
          mailAddresses = ["kristoffer@dalby.cc"];
          groups = [];
        };
      };

      groups = {
        vpn_users.members = ["kradalby"];
      };

      systems.oauth2.headscale = {
        originUrl = "https://headscale.kradalby.no/oidc/callback";
        originLanding = "https://headscale.kradalby.no";
        displayName = "Headscale";
        scopeMaps.vpn_users = ["openid" "profile" "email"];
        basicSecretFile = config.age.secrets.kanidm-headscale-oidc-secret.path;
      };
    };
  };

  users.groups.kanidm = {
    members = ["nginx"];
  };

  security.acme.certs."${domain}" = {
    postRun = "systemctl restart kanidm.service";
    group = "kanidm";
  };

  services.nginx.virtualHosts."${domain}" = {
    useACMEHost = domain;
    forceSSL = true;
    locations."/" = {
      proxyPass = "https://127.0.0.1:3013";
    };
  };
}
