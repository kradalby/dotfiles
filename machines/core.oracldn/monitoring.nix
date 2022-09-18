{ pkgs, config, lib, ... }:
let
  prometheusDomain = "prometheus.${config.networking.domain}";
  pushgatewayDomain = "pushgateway.${config.networking.domain}";
in
{
  services.prometheus = {
    enable = true;

    retentionTime = "365d";

    scrapeConfigs = [
      {
        job_name = "consul";
        consul_sd_configs = [
          { server = "consul.ldn.fap.no"; }
          { server = "consul.ntnu.fap.no"; }
          { server = "consul.tjoda.fap.no"; }
        ];
        relabel_configs = [
          {
            source_labels = [
              "__meta_consul_tags"
            ];
            regex = ".*,prometheus,.*";
            action = "keep";
          }
          {
            source_labels = [
              "__meta_consul_node"
              "__meta_consul_dc"
              "__meta_consul_service_port"
            ];
            regex = "([a-z]+);([a-z]+);([0-9]+)";
            replacement = "$1.$2.fap.no:$3";
            target_label = "instance";
          }
          {
            source_labels = [
              "__meta_consul_dc"
            ];
            replacement = "$1";
            target_label = "site";
          }
          {
            source_labels = [
              "__meta_consul_service"
            ];
            target_label = "job";
          }
        ];
      }
    ];

    # alertmanager = {
    #   enable = true;
    #
    #   listenAddress = "localhost";
    #
    #   webExternalUrl = "https://alertmanager.oracldn.fap.no";
    # };

    pushgateway = {
      enable = true;

      web = {
        external-url = "https://pushgateway.oracldn.fap.no";
        listen-address = "localhost:9091";
      };

      persistMetrics = true;
    };
  };

  security.acme.certs."${prometheusDomain}".domain = prometheusDomain;

  services.nginx.virtualHosts."${prometheusDomain}" = {
    forceSSL = true;
    useACMEHost = prometheusDomain;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.prometheus.port}";
      # proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${prometheusDomain}.access.log;
    '';
  };

  security.acme.certs."${pushgatewayDomain}".domain = pushgatewayDomain;

  services.nginx.virtualHosts."${pushgatewayDomain}" = {
    forceSSL = true;
    useACMEHost = pushgatewayDomain;
    locations."/" = {
      proxyPass = "http://${config.services.prometheus.pushgateway.web.listen-address}";
      # proxyWebsockets = true;
    };
    extraConfig = ''
      access_log /var/log/nginx/${pushgatewayDomain}.access.log;
    '';
  };
}
