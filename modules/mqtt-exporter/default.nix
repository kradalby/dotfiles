{ config, pkgs, lib, ... }:

with lib;

let
  packageOverrides = pkgs.callPackage ./python-packages.nix { };
  python = pkgs.python3.override { inherit packageOverrides; };
  pythonWithPackages = python.withPackages (ps: [ ps."paho-mqtt" ps."prometheus-client" ]);

  mqttExporter = builtins.fetchGit {
    url = "https://github.com/kpetremann/mqtt-exporter.git";
    ref = "master";
    rev = "7c7a828e85f732160d1e3587dd88d90c6e164ab5";
  };

  cfg = config.services.mqtt-exporter;
in
{

  options.services.mqtt-exporter = {
    enable = mkEnableOption "MQTT exporter for Prometheus, exposing zigbee2mqtt metrics.";

    package = mkOption {
      type = types.package;
      description = ''
        MQTT exporter package to use
      '';
      default = pythonWithPackages;
      defaultText = literalExpression "python with overridden dependencies";
    };

    mqtt.ignoredTopics = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Lists of topics to ignore";
    };

    logLevel = mkOption {
      type = types.str;
      default = "INFO";
      description = "Logging level";
    };

    mqtt.address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IP or hostname of MQTT broker";
    };

    mqtt.port = mkOption {
      type = types.port;
      default = 1883;
      description = "TCP port of MQTT broker";
    };

    mqtt.topic = mkOption {
      type = types.str;
      default = "#";
      description = "Topic path to subscribe to";
    };

    mqtt.keepalive = mkOption {
      type = types.int;
      default = 60;
      description = "Keep alive interval to maintain connection with MQTT broker";
    };

    mqtt.username = mkOption {
      type = types.str;
      default = "";
      description = "Username which should be used to authenticate against the MQTT broker";
    };

    mqtt.password = mkOption {
      type = types.str;
      default = "";
      description = "Password which should be used to authenticate against the MQTT broker";
    };


    prometheus.port = mkOption {
      type = types.port;
      default = 9000;
      description = "HTTP server PORT to expose Prometheus metrics";
    };

    prometheus.prefix = mkOption {
      type = types.str;
      default = "";
      description = "Prefix added to the metric name, example: mqtt_temperature (default: mqtt_)";
    };

    prometheus.topicLabel = mkOption {
      type = types.str;
      default = "topic";
      description = ''Define the Prometheus label for the topic, example temperature{topic="device1"}'';
    };

    user = mkOption {
      type = types.str;
      default = "mosquitto";
      description = "User account under which MQTT exporter runs.";
    };

    group = mkOption {
      type = types.str;
      default = "mosquitto";
      description = "Group account under which MQTT exporter runs.";
    };

    openFirewall = mkEnableOption "opening of the metric in the firewall";

  };

  config = mkIf cfg.enable {

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 9000 ];

    systemd.services.mqtt-exporter = {
      enable = true;
      script = ''
        ${pythonWithPackages}/bin/python ${mqttExporter}/exporter.py
      '';
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "zigbee2mqtt.service" "mosquitto.service" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "15";
      };
      environment = {
        IGNORED_TOPICS = builtins.concatStringsSep "," cfg.mqtt.ignoredTopics;
        LOG_LEVEL = cfg.logLevel;
        MQTT_ADDRESS = cfg.mqtt.address;
        MQTT_PORT = toString cfg.mqtt.port;
        MQTT_KEEPALIVE = toString cfg.mqtt.keepalive;
        MQTT_USERNAME = cfg.mqtt.username;
        MQTT_PASSWORD = cfg.mqtt.password;
        PROMETHEUS_PORT = toString cfg.prometheus.port;
        PROMETHEUS_PREFIX = cfg.prometheus.prefix;
        TOPIC_LABEL = cfg.prometheus.topicLabel;
      };

      preStart = ''
    '';

    };
  };
}
