{
  config,
  pkgs,
  lib,
  system,
  ...
}: let
  domain = "scrypted.${config.networking.domain}";

  dataDir = "/var/lib/scrypted";

  scryptedPackages = import ../../modules/scrypted/override.nix {inherit pkgs system;};
  packageModulePath = package: "${package}/lib/node_modules/";
  nodeModulePaths = map packageModulePath (builtins.attrValues scryptedPackages);
  nodePath = builtins.concatStringsSep ":" nodeModulePaths;
  scryptedWrapped = pkgs.stdenv.mkDerivation rec {
    version = "1.0.0";
    name = "scrypted-${version}";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/scrypted <<EOF
      #!/bin/sh
      NODE_PATH=${nodePath} exec ${scryptedPackages.scrypted}/bin/scrypted serve
      EOF
      chmod +x $out/bin/scrypted
    '';
  };
in {
  users.users.scrypted = {
    home = dataDir;
    createHome = true;
    group = "scrypted";
    isSystemUser = false;
    isNormalUser = true;
    description = "Home Bridge";
  };

  users.groups.scrypted = {};

  # networking.firewall.allowedTCPPorts = [ scryptedConfig.bridge.port ];
  # networking.firewall.allowedUDPPorts = [ scryptedConfig.bridge.port 1900 5350 5351 5353 ];

  systemd.services.scrypted = {
    enable = true;
    restartTriggers = [scryptedWrapped];
    script = "exec ${scryptedWrapped}/bin/scrypted";
    wantedBy = ["multi-user.target"];
    after = ["network.target"];
    serviceConfig = {
      User = "scrypted";
      Restart = "always";
      RestartSec = "15";
      # CapabilityBoundingSet = "CAP_NET_RAW";
      AmbientCapabilities = "CAP_NET_RAW";
    };
    environment = {};

    onFailure = ["notify-discord@%n.service"];

    # preStart = ''
    #   cp -f ${configFile} ${dataDir}/config.json
    # '';
  };

  # security.acme.certs."${domain}".domain = domain;
  #
  # services.nginx.virtualHosts."${domain}" = {
  #   forceSSL = true;
  #   useACMEHost = domain;
  #   locations."/" = {
  #     proxyPass = "http://127.0.0.1:${toString scryptedUIPort}";
  #     # proxyWebsockets = true;
  #   };
  # extraConfig = ''
  #   access_log /var/log/nginx/${domain}.access.log;
  # '';
  # };
}
