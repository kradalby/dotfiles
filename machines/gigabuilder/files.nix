{ ... }:
let
  domain = "files.kradalby.no";
in
{
  systemd.tmpfiles.rules = [ "d /var/lib/files 0755 root root -" ];

  # Offsite via the Jotta proxy on core.tjoda (no Jotta credentials here).
  # targetHost is the opaque repo name on Jotta — house convention, nothing
  # host-identifying on the provider side.
  services.restic.jobs.jotta = {
    enable = true;
    site = "jotta";
    targetHost = "58e7021d53e2678171cbd27eadf356be";
    secret = "restic-gigabuilder-token";
    paths = [
      "/var/lib/files"
      "/root"
      "/etc/nixos"
    ];
    # Brand-new repo: create it on first run, then flip this off.
    initialize = true;
    # Jotta egress is paid/slow: verify metadata only, monthly. (Same as the
    # other jotta jobs.)
    check = {
      args = [ ];
      interval = "monthly";
    };
  };

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
