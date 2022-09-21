{
  config,
  pkgs,
  lib,
  system,
  ...
}: let
  domain = "homebridge.${config.networking.domain}";

  dataDir = "/var/lib/homebridge";

  homebridgeConfig = import ./homebridgeConfig.nix;
  configFile = pkgs.writeText "config.json" (builtins.toJSON homebridgeConfig);

  homebridgeUIPort = (builtins.elemAt homebridgeConfig.platforms 0).port;

  # startupFile = pkgs.writeText "startup.sh" ''
  #   #!/bin/sh
  #   npm install --unsafe-perm homebridge-mqttthing
  #   npm install --unsafe-perm homebridge-xiaomi-roborock-vacuum@latest
  #   npm install --unsafe-perm homebridge-philips-tv6
  # '';

  tradfriCodec = builtins.fetchGit {
    url = "https://github.com/kradalby/tradfri-mqttthing.git";
    ref = "master";
    rev = "c09fe38ce0ae58f1c9216b9dfcb7e05d641eebbe";
  };
in {
  users.users.homebridge = {
    home = dataDir;
    createHome = true;
    group = "homebridge";
    extraGroups = ["video"];
    isSystemUser = false;
    isNormalUser = true;
    description = "Home Bridge";
  };

  users.groups.homebridge = {};

  networking.firewall.allowedTCPPorts = [homebridgeConfig.bridge.port];
  networking.firewall.allowedUDPPorts = [homebridgeConfig.bridge.port 1900 5350 5351 5353];

  systemd.services.homebridge = {
    enable = true;
    # confinement = {
    #   enable = true;
    #   mode = "chroot-only";
    # };
    restartTriggers = [pkgs.homebridge];
    script = "exec ${pkgs.homebridge}/bin/homebridge";
    wantedBy = ["multi-user.target"];
    after = ["network.target" "zigbee2mqtt.service" "mosquitto.service"];
    serviceConfig = {
      User = "homebridge";
      Restart = "always";
      RestartSec = "15";
      # CapabilityBoundingSet = "CAP_NET_RAW";
      AmbientCapabilities = "CAP_NET_RAW";
      DeviceAllow = ["/dev/v4l/by-id/usb-046d_0825_A4221F10-video-index0"];
    };
    path = [pkgs.ffmpeg];
    environment = {
      HOMEBRIDGE_INSECURE = "1";
      HOMEBRIDGE_CONFIG_UI = "1";
      HOMEBRIDGE_CONFIG_UI_PORT = toString homebridgeUIPort;
    };

    onFailure = ["notify-discord@%n.service"];

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
