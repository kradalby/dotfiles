{ config, ... }:
{
  # zigbee2mqtt publishes to z2m-homekit's embedded broker (:51833,
  # localhost, no auth); tasmota energy data comes via the tasmota-exporter
  # HTTP probes, not MQTT.
  services.mqtt-exporter = {
    enable = true;
    # The broker is z2m-homekit's embedded one, not zigbee2mqtt itself.
    brokerUnit = "z2m-homekit.service";

    mqtt = {
      port = config.services.z2m-homekit.ports.mqtt;
      keepalive = 30;
    };

    prometheus = {
      prefix = "sensor_";
      topicLabel = "sensor";
    };
  };

  # Tailnet-only scrape: tailscale0-scoped like the other exporters, not the
  # global open the module's openFirewall would add.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    config.services.mqtt-exporter.prometheus.port
  ];
}
