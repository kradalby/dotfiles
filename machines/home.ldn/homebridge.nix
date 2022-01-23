{ config, pkgs, lib, ... }:
let
  domain = "homebridge.${config.networking.domain}";

  dataDir = "/var/lib/homebridge";

  homebridgeConfig = import ./homebridgeConfig.nix;
  configFile = pkgs.writeText "config.json" (builtins.toJSON homebridgeConfig);

  homebridgeUIPort = (builtins.elemAt homebridgeConfig.platforms 0).port;

  startupFile = pkgs.writeText "startup.sh" ''
    #!/bin/sh
    npm install --unsafe-perm homebridge-mqttthing
    npm install --unsafe-perm homebridge-xiaomi-roborock-vacuum@latest
    npm install --unsafe-perm homebridge-philips-tv6
  '';

  tradfriCodec = builtins.fetchGit {
    url = "https://github.com/kradalby/tradfri-mqttthing.git";
    ref = "master";
    rev = "c09fe38ce0ae58f1c9216b9dfcb7e05d641eebbe";
  };

  homebridgePackages = import ../../modules/homebridge { inherit pkgs; };
  packageModulePath = package: "${package}/lib/node_modules/";
  nodeModulePaths = map packageModulePath (builtins.attrValues homebridgePackages);
  nodePath = builtins.concatStringsSep ":" nodeModulePaths;
  homebridgeWrapped = pkgs.stdenv.mkDerivation rec {
    version = "1.0.0";
    name = "homepi-server-${version}";
    unpackPhase = "true";
    buildPhase = "true";
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/homebridge <<EOF
      #!/bin/sh
      NODE_PATH=${nodePath} exec ${homebridgePackages.homebridge}/bin/homebridge -D -U ~/ -I "$@"
      EOF
      chmod +x $out/bin/homebridge
    '';
  };
in
{
  users.users.homebridge = {
    home = dataDir;
    createHome = true;
    group = "homebridge";
    isSystemUser = false;
    isNormalUser = true;
    description = "Home Bridge";
  };

  users.groups.homebridge = { };

  networking.firewall.allowedTCPPorts = [ homebridgeConfig.bridge.port ];
  networking.firewall.allowedUDPPorts = [ homebridgeConfig.bridge.port 1900 5350 5351 5353 ];

  systemd.services.homebridge = {
    enable = true;
    # confinement = {
    #   enable = true;
    #   mode = "chroot-only";
    # };
    restartTriggers = [ homebridgeWrapped ];
    script = "exec ${homebridgeWrapped}/bin/homebridge";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "zigbee2mqtt.service" "mosquitto.service" ];
    serviceConfig = {
      User = "homebridge";
      Restart = "always";
      RestartSec = "15";
      # CapabilityBoundingSet = "CAP_NET_RAW";
      AmbientCapabilities = "CAP_NET_RAW";
    };
    environment = {
      HOMEBRIDGE_INSECURE = "1";
      HOMEBRIDGE_CONFIG_UI = "1";
      HOMEBRIDGE_CONFIG_UI_PORT = (toString homebridgeUIPort);
    };

    onFailure = [ "notify-discord@%n.service" ];

    preStart = ''
      ln -sf ${configFile} ${dataDir}/config.json
      ln -sf ${tradfriCodec}/cie-rgb-converter.js ${dataDir}/cie-rgb-converter.js
      ln -sf ${tradfriCodec}/tradfri-codec.js ${dataDir}/tradfri-codec.js
    '';
  };


  # virtualisation.oci-containers.containers.homebridge = {
  #   image = "oznu/homebridge:no-avahi-arm64v8";
  #   # user = "podmanager";
  #   # workdir = "/home/podmanager";
  #   autoStart = true;
  #   ports = [
  #     "8581:8581/tcp"
  #     "51781:51781/tcp"
  #     "51781:51781/udp"
  #     "1900:1900/udp"
  #     "5350:5350/udp"
  #     "5351:5351/udp"
  #     "5353:5353/udp"
  #   ];
  #   environment = {
  #     # PGID = "${config.users.groups.homebridge.gid}";
  #     # PUID = "${config.users.users.homebridge.uid}";
  #     HOMEBRIDGE_CONFIG_UI = "1";
  #     HOMEBRIDGE_CONFIG_UI_PORT = "8581";
  #     TZ = "UTC";
  #   };
  #   volumes = [
  #     "/var/lib/homebridge:/homebridge"
  #   ];
  # };

  security.acme.certs."${domain}".domain = domain;

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = domain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString homebridgeUIPort}";
      # proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${domain}.access.log;
    '';
  };
}
