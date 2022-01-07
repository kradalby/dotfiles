{ config, pkgs, lib, ... }:
let
  dataDir = "/var/lib/homebridge";

  homebridgeConfig = import ./homebridgeConfig.nix;
  configFile = pkgs.writeText "config.json" (builtins.toJSON homebridgeConfig);

  startupFile = pkgs.writeText "startup.sh" ''
    #!/bin/sh
    npm install --unsafe-perm homebridge-mqttthing
    npm install --unsafe-perm homebridge-xiaomi-roborock-vacuum@latest
    npm install --unsafe-perm homebridge-philips-tv6
  '';

  cieRgbConvert = pkgs.fetchurl {
    url = "https://github.com/kradalby/tradfri-mqttthing/raw/master/cie-rgb-converter.js";
    sha256 = "sha256-7FX+T2IXDc+3SUV1N/b3W1+ZmB8mNANGHdMJzcBKK6A=";
  };

  tradfriCodec = pkgs.fetchurl {
    url = "https://github.com/kradalby/tradfri-mqttthing/raw/master/tradfri-codec.js";
    sha256 = "sha256-5nizIgxi34GTYXLHJ6JLavRhX/6FAGj0JV58UB7Kis0=";
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
      NODE_PATH=${nodePath} exec ${homebridgePackages.homebridge}/bin/homebridge -U ~/ -I "$@"
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

  networking.firewall.allowedTCPPorts = [ 51781 ];
  networking.firewall.allowedUDPPorts = [ 51781 1900 5350 5351 5353 ];

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
      HOMEBRIDGE_CONFIG_UI_PORT = "8581";
    };

    onFailure = [ "notify-email@%n.service" ];

    preStart = ''
      cp -f ${configFile} ${dataDir}/config.json
      cp -f ${cieRgbConvert} ${dataDir}/cie-rgb-converter.js
      cp -f ${tradfriCodec} ${dataDir}/tradfri-codec.js
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

  security.acme.certs."homebridge.ldn.fap.no".domain = "homebridge.ldn.fap.no";

  services.nginx.virtualHosts."homebridge.ldn.fap.no" = {
    forceSSL = true;
    useACMEHost = "homebridge.ldn.fap.no";
    locations."/" = {
      proxyPass = "http://127.0.0.1:8581";
      # proxyWebsockets = true;
    };
  };
}
