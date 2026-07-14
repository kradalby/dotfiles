{ ... }:
let
  domain = "files.kradalby.no";
in
{
  # TODO: no restic here yet; /var/lib/files is unbacked until then.
  systemd.tmpfiles.rules = [ "d /var/lib/files 0755 root root -" ];

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      root = "/var/lib/files";
      extraConfig = ''
        autoindex on;
      '';
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
