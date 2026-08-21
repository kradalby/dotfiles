{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
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
      default = pkgs.python3.withPackages (ps: [
        ps.paho-mqtt
        ps.prometheus-client
      ]);
      defaultText = literalExpression "python3 with the exporter's dependencies";
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

    openFirewall = mkEnableOption "opening of the metric in the firewall";

    brokerUnit = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "z2m-homekit.service";
      description = "systemd unit providing the MQTT broker, for start ordering (the exporter self-heals via Restart either way).";
    };
  };

  config = mkIf cfg.enable (
    let
      mqttExporterSrc = pkgs.fetchFromGitHub {
        owner = "kpetremann";
        repo = "mqtt-exporter";
        rev = "v1.11.2";
        hash = "sha256-pWXdd82K1BhUKHGVGpTRW4f/Xa9nf0Ww/l2pxdw/Jw8=";
      };
    in
    {
      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.prometheus.port ];

      systemd.services.mqtt-exporter = {
        enable = true;
        script = ''
          ${cfg.package}/bin/python ${mqttExporterSrc}/exporter.py
        '';
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ] ++ lib.optional (cfg.brokerUnit != null) cfg.brokerUnit;
        serviceConfig = {
          # Stateless localhost subscriber — no reason for a real account.
          DynamicUser = true;
          Restart = "always";
          RestartSec = "15";
        };
        environment = {
          MQTT_IGNORED_TOPICS = builtins.concatStringsSep "," cfg.mqtt.ignoredTopics;
          LOG_LEVEL = cfg.logLevel;
          MQTT_ADDRESS = cfg.mqtt.address;
          MQTT_PORT = toString cfg.mqtt.port;
          MQTT_TOPIC = cfg.mqtt.topic;
          MQTT_KEEPALIVE = toString cfg.mqtt.keepalive;
          MQTT_USERNAME = cfg.mqtt.username;
          MQTT_PASSWORD = cfg.mqtt.password;
          PROMETHEUS_PORT = toString cfg.prometheus.port;
          PROMETHEUS_PREFIX = cfg.prometheus.prefix;
          TOPIC_LABEL = cfg.prometheus.topicLabel;
        };
      };
    }
  );
}
