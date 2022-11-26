{
  config,
  pkgs,
  lib,
  system,
  ...
}: let
  domain = "uptime.kradalby.no";

  dataDir = "/var/lib/kuma";

  port = 3001;

  kumaPackages = import ../../modules/uptime-kuma/override.nix {inherit pkgs system;};
  packageModulePath = package: "${package}/lib/node_modules/";
  nodeModulePaths = map packageModulePath (builtins.attrValues kumaPackages);
  nodePath = builtins.concatStringsSep ":" nodeModulePaths;
  kumaWrapped = pkgs.stdenv.mkDerivation rec {
    version = "1.0.0";
    name = "kuma-${version}";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/kuma <<EOF
      #!/bin/sh
      NODE_PATH=${nodePath} ${pkgs."nodejs-14_x"}/bin/node ${kumaPackages."uptime-kuma-git://github.com/louislam/uptime-kuma.git"}/lib/node_modules/uptime-kuma/server/server.js
      EOF
      chmod +x $out/bin/kuma
    '';
  };
in {
  users.users.kuma = {
    home = dataDir;
    createHome = true;
    group = "kuma";
    isSystemUser = false;
    isNormalUser = true;
    description = "uptime-kuma";
  };

  users.groups.kuma = {};

  # networking.firewall.allowedTCPPorts = [ kumaConfig.bridge.port ];
  # networking.firewall.allowedUDPPorts = [ kumaConfig.bridge.port 1900 5350 5351 5353 ];

  # systemd.services.kuma = {
  #   enable = true;
  #   restartTriggers = [ kumaWrapped ];
  #   script = "exec ${kumaWrapped}/bin/kuma";
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network.target" ];
  #   serviceConfig = {
  #     User = "kuma";
  #     Restart = "always";
  #     RestartSec = "15";
  #     # CapabilityBoundingSet = "CAP_NET_RAW";
  #     AmbientCapabilities = "CAP_NET_RAW";
  #   };
  #   environment = { };
  #

  #
  #   preStart = ''
  #   '';
  # };

  virtualisation.oci-containers.containers.kuma = {
    image = "louislam/uptime-kuma:1.16.0";
    # user = "kuma";
    # workdir = "/home/podmanager";
    autoStart = true;
    ports = [
      "${toString port}:3001/tcp"
    ];
    environment = {};
    volumes = [
      "/var/lib/kuma:/app/data"
    ];
  };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
