{config, ...}: let
  domain = "auth.kradalby.no";
in {
  services.kanidm.enableServer = true;
  services.kanidm.serverSettings = {
    inherit domain;
    tls_chain = "/var/lib/acme/${domain}/fullchain.pem";
    tls_key = "/var/lib/acme/${domain}/key.pem";
    bindaddress = "[::1]:3013";
    ldapbindaddress = "[::1]:3636";
    origin = "https://${domain}";
    trust_x_forward_for = true;
    db_fs_type = "xfs";

    online_backup = {
      path = "/var/lib/kanidm/backup";
      schedule = "0 0 * * *";
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
      proxyPass = "https://[::1]:3013";
    };
  };
}
