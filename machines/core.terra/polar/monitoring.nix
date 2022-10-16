{
  pkgs,
  config,
  lib,
  ...
}: let
  meta = import ./meta.nix {};

  prometheusDomain = "prometheus.${config.networking.domain}";
  # pushgatewayDomain = "pushgateway.${config.networking.domain}";

  upstreamSnmpConf =
    builtins.replaceStrings [
      "if_mib:"
    ] [
      ''
        if_mib:
          version: 2
          auth:
            community: JqbvUFuze

      ''
    ] (builtins.readFile (builtins.fetchurl "https://github.com/prometheus/snmp_exporter/raw/main/snmp.yml"));

  snmpPublic = ''
    default:
      version: 2
      auth:
        community: JqbvUFuze
  '';

  snmpConf = pkgs.writeText "snmp.yaml" ''
    ${snmpPublic}
    ${upstreamSnmpConf}
  '';

  junosConf = {
    # devices = [
    #   {
    #     host = ".*";
    #     host_pattern = true;
    #     username = "tech";
    #     password = "";
    #   }
    # ];

    devices =
      builtins.map (host: {
        host = host + ".pp30.polarparty.no";
        username = "tech";
        password = "";
      })
      meta.juniperSwitches;

    features = {
      alarm = false;
      environment = false;
      bgp = false;
      ospf = false;
      isis = false;
      nat = false;
      l2circuit = false;
      ldp = false;
      routes = false;
      routing_engine = false;
      firewall = false;
      interfaces = true;
      interface_diagnostic = false;
      interface_queue = false;
      storage = false;
      accounting = false;
      ipsec = false;
      security = false;
      fpc = false;
      rpki = false;
      rpm = false;
      satellite = false;
      system = false;
      power = false;
    };
  };

  settingsFormat = pkgs.formats.yaml {};
  configFile = settingsFormat.generate "junos-exporter.yaml" junosConf;
in {
  services.prometheus = {
    enable = true;
    package = pkgs.unstable.prometheus;

    retentionTime = "14d";

    scrapeConfigs = [
      {
        job_name = "polar-snmp";
        scrape_interval = "5m";
        scrape_timeout = "4m30s";
        static_configs = [
          {
            targets = builtins.map (sw: "${sw}.pp30.polarparty.no") meta.switches;
          }
        ];
        metrics_path = "/snmp";
        params = {
          module = ["if_mib"];
        };
        relabel_configs = [
          {
            "source_labels" = ["__address__"];
            "target_label" = "__param_target";
          }
          {
            "source_labels" = ["__param_target"];
            "target_label" = "instance";
          }
          {
            "target_label" = "__address__";
            "replacement" = "127.0.0.1:${toString config.services.prometheus.exporters.snmp.port}";
          }
        ];
      }
      {
        job_name = "polar-arista";
        scrape_interval = "2m";
        scrape_timeout = "1m59s";
        static_configs = [
          {
            targets = builtins.map (sw: "${sw}.pp30.polarparty.no") meta.aristaSwitches;
          }
        ];
        metrics_path = "/arista";
        scheme = "https";
        params = {
          module = ["port"];
        };
        relabel_configs = [
          {
            "source_labels" = ["__address__"];
            "target_label" = "__param_target";
          }
          {
            "source_labels" = ["__param_target"];
            "target_label" = "instance";
          }
          {
            "target_label" = "__address__";
            "replacement" = "arista-exporter.nms.pp30.polarparty.no:443";
          }
        ];
      }
      {
        job_name = "polar-juniper";
        scrape_interval = "30s";
        scrape_timeout = "29s";
        static_configs = [
          {
            targets = builtins.map (sw: "${sw}.pp30.polarparty.no") meta.juniperSwitches;
          }
        ];
        relabel_configs = [
          {
            "source_labels" = ["__address__"];
            "target_label" = "__param_target";
          }
          {
            "source_labels" = ["__param_target"];
            "target_label" = "instance";
          }
          {
            "target_label" = "__address__";
            "replacement" = "127.0.0.1:9326";
          }
        ];
      }
      # {
      #   job_name = "consul";
      #   consul_sd_configs = [
      #     {server = "consul.ldn.fap.no";}
      #     {server = "consul.ntnu.fap.no";}
      #     {server = "consul.tjoda.fap.no";}
      #   ];
      #   relabel_configs = [
      #     {
      #       source_labels = [
      #         "__meta_consul_tags"
      #       ];
      #       regex = ".*,prometheus,.*";
      #       action = "keep";
      #     }
      #     {
      #       source_labels = [
      #         "__meta_consul_node"
      #         "__meta_consul_dc"
      #         "__meta_consul_service_port"
      #       ];
      #       regex = "([a-z]+);([a-z]+);([0-9]+)";
      #       replacement = "$1.$2.fap.no:$3";
      #       target_label = "instance";
      #     }
      #     {
      #       source_labels = [
      #         "__meta_consul_dc"
      #       ];
      #       replacement = "$1";
      #       target_label = "site";
      #     }
      #     {
      #       source_labels = [
      #         "__meta_consul_service"
      #       ];
      #       target_label = "job";
      #     }
      #   ];
      # }
    ];
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

  # security.acme.certs."${pushgatewayDomain}".domain = pushgatewayDomain;
  #
  # services.nginx.virtualHosts."${pushgatewayDomain}" = {
  #   forceSSL = true;
  #   useACMEHost = pushgatewayDomain;
  #   locations."/" = {
  #     proxyPass = "http://${config.services.prometheus.pushgateway.web.listen-address}";
  #     # proxyWebsockets = true;
  #   };
  #   extraConfig = ''
  #     access_log /var/log/nginx/${pushgatewayDomain}.access.log;
  #   '';
  # };

  systemd.services.junos-exporter = {
    enable = true;
    script = ''
      ${pkgs.junos_exporter}/bin/junos_exporter -debug -config.file ${configFile}
    '';
    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    serviceConfig = {
      User = "prometheus";
      Group = "prometheus";
      Restart = "always";
      RestartSec = "15";
      WorkingDirectory = "";
    };
    path = [pkgs.junos_exporter];
    environment = {};
  };

  services.prometheus.exporters.snmp = {
    enable = true;
    # configuration = {
    #   default = {
    #     auth = {
    #       community = "JqbvUFuze";
    #     };
    #     version = 2;
    #   };
    # };
    configurationPath = snmpConf;
  };
}
