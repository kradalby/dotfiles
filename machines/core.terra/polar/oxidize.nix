{
  pkgs,
  config,
  lib,
  ...
}: let
  meta = import ./meta.nix {};

  domain = "ox.core.terra.fap.no";
  conf = pkgs.writeText "oxidized-config.yml" ''
    ---
    debug: true
    use_syslog: true
    input:
      default: ssh
      ssh:
        secure: false
    output:
      default: git
      git:
        single_repo: true
        user: Oxidized
        email: oxidize@polarparty.no
        repo: "${config.services.oxidized.dataDir}/default.git"
    interval: 3600
    source:
      default: csv
      csv:
        delimiter: !ruby/regexp /:/
        file: "${config.services.oxidized.routerDB}"
        map:
          name: 0
          model: 1
    rest: 127.0.0.1:8888
    retries: 3
    models:
      eos:
        vars:
          auth_methods:
            - none
            - publickey
            - password
            - keyboard-interactive
        username: tech
        password: 
      junos:
        username: tech
        password: 
  '';
in {
  config = {
    services.oxidized = {
      enable = true;

      routerDB = pkgs.writeText "oxidized-router.db" (lib.concatStringsSep "\n" (
        (builtins.map (name: "${name}.pp30.polarparty.no:eos")
          meta.aristaSwitches)
        ++ (builtins.map (name: "${name}.pp30.polarparty.no:junos") meta.juniperSwitches)
      ));

      configFile = conf;
    };

    security.acme.certs."${domain}".domain = domain;

    services.nginx.virtualHosts."${domain}" = {
      forceSSL = true;
      useACMEHost = domain;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8888";
      };
      extraConfig = ''
        access_log /var/log/nginx/${domain}.access.log;
      '';
      basicAuth = {tech = "techyteck";};
    };
  };
}
