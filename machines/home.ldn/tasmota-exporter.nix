{
  pkgs,
  config,
  lib,
  ...
}: let
  consul = import ../../common/funcs/consul.nix {inherit lib;};
  port = 9092;
  package = pkgs.tasmota-exporter;
in {
  systemd.services.tasmota-exporter = {
    enable = true;
    description = "tasmota exporter";
    script = ''
      ${package}/bin/cmd
    '';
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];

    serviceConfig = {
      DynamicUser = true;
      Restart = "always";
      RestartSec = "15";
    };
    environment = {
      MQTT_HOSTNAME = "localhost";
      MQTT_PORT = "1883";
      MQTT_USERNAME = "exporter";
      MQTT_PASSWORD = "prometheus";
      MQTT_CLIENT_ID = "prometheus_tasmota_exporter";
      # MQTT_TOPICS //default is "tele/+/+, stat/+/+". If you're using deeper topics, you can set as "tele/#, stat/#"
      PROMETHEUS_EXPORTER_PORT = toString port;
      REMOVE_WHEN_INACTIVE_MINUTES = "5";
      STATUS_UPDATE_SECONDS = "10";
    };

    path = [package];
  };

  my.consulServices.tasmota_exporter = consul.prometheusExporter "tasmota" port;
  networking.firewall.allowedTCPPorts = [port];
}
