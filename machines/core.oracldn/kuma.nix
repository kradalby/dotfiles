{
  config,
  pkgs,
  lib,
  system,
  ...
}:
let
  domain = "uptime.kradalby.no";
in
{
  services.uptime-kuma = {
    enable = true;
  };

  users.users.uptime-kuma = {
    name = "uptime-kuma";
    isSystemUser = true;
    home = "/var/lib/uptime-kuma";
    homeMode = "2770";
    createHome = true;
    group = "uptime-kuma";
  };
  users.groups.uptime-kuma = { };

  # Nixpkgs chmods a freshly copied template to 0640. Pre-create it with
  # shared write access so Kuma skips that copy; never replace an existing DB.
  systemd.services.uptime-kuma.preStart = ''
    db=${lib.escapeShellArg "${config.users.users.uptime-kuma.home}/kuma.db"}
    if [ ! -e "$db" ]; then
      ${pkgs.coreutils}/bin/install -m 0660 \
        ${config.services.uptime-kuma.package}/lib/node_modules/uptime-kuma/db/kuma.db "$db"
    fi
    ${pkgs.coreutils}/bin/chmod 0660 "$db"
  '';

  systemd.services.uptime-kuma.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = config.users.users.uptime-kuma.name;
    Group = config.users.users.uptime-kuma.name;
    WorkingDirectory = config.users.users.uptime-kuma.home;
    # Litestream shares this group. Keep fresh state, DBs and WAL files
    # writable by both services, including files created by the replica.
    StateDirectoryMode = lib.mkForce "2770";
    UMask = lib.mkForce "0007";
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
