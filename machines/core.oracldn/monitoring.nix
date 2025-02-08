{
  pkgs,
  config,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  prometheusDomain = "prometheus.${config.networking.domain}";
  pushgatewayDomain = "pushgateway.${config.networking.domain}";

  blackboxConfigFile = pkgs.writeText "blackbox.conf" ''
    modules:
      http_prometheus:
        prober: http
        timeout: 5s
        http:
          method: GET
          valid_http_versions: ["HTTP/1.1", "HTTP/2"]
          fail_if_ssl: false
          fail_if_not_ssl: false
      icmp:
        prober: icmp
        timeout: 10s
        icmp:
          preferred_ip_protocol: ip4
  '';
  scrapeJob = name: targets: {
    job_name = name;
    metrics_path = "/metrics";
    static_configs = [
      {
        targets = targets;
      }
    ];
  };
in
  lib.mkMerge [
    {
      services.tailscale-proxies = {
        prometheus = {
          enable = true;
          tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

          hostname = "prom";
          backendPort = config.services.prometheus.port;
        };
        alertmanager = {
          enable = true;
          tailscaleKeyPath = config.age.secrets.tailscale-preauthkey.path;

          hostname = "alertmanager";
          backendPort = config.services.prometheus.alertmanager.port;
        };
      };

      age.secrets.alertmanager-env = {
        file = ../../secrets/alertmanager-env.age;
        owner = config.systemd.services.prometheus.serviceConfig.User;
      };

      services.prometheus = {
        enable = true;

        retentionTime = "365d";
        webExternalUrl = "http://prom/";

        alertmanagers = [
          {
            scheme = "http";
            path_prefix = "/";
            static_configs = [{targets = ["localhost:${toString config.services.prometheus.alertmanager.port}"];}];
          }
        ];

        scrapeConfigs = [
          {
            job_name = "consul";
            consul_sd_configs = [
              {server = "consul.ldn.fap.no";}
              {server = "consul.oracldn.fap.no";}
              {server = "consul.oracfurt.fap.no";}
              {server = "consul.tjoda.fap.no";}
              {server = "consul.terra.fap.no";}
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
          {
            job_name = "tjoda-ping";
            metrics_path = "/probe";
            params = {
              module = ["icmp"];
            };
            static_configs = [
              {
                targets = [
                  # Unifi
                  "hus-kontor-printer.tjoda"
                  "love-kontor-printer.tjoda"
                  "hus-kontor-switch.tjoda"
                  "love-loft-switch.tjoda"
                  "love-kontor-switch.tjoda"
                  "love-scene-switch.tjoda"
                  "bryggerhus-switch.tjoda"
                  "hus-kontor-ap.tjoda"
                  "hus-spisestue-ap.tjoda"
                  "love-scene-ap.tjoda"
                  "love-selskap-ap.tjoda"
                  "love-lager-ap.tjoda"
                  "bryggerhus-ap.tjoda"

                  # Sonos hus
                  "hus-kjokken-sonos.tjoda"
                  "hus-salong-sonos.tjoda"
                  "hus-spisestue-sonos.tjoda"
                  "hus-kontor-sonos.tjoda"
                  "hus-gang-sonos.tjoda"
                  "hus-hage-sonos.tjoda"

                  # Sonos låve
                  "love-kontor-bridge-sonos.tjoda"
                  "love-salong-sonos.tjoda"
                  "love-spisestue-sonos.tjoda"
                  "love-dansegulv-sonos.tjoda"
                  # "love-loft-sonos.tjoda"

                  # Atlas probe
                  "atlas-probe.tjoda"
                ];
              }
            ];
            relabel_configs = [
              {
                source_labels = ["__address__"];
                target_label = "__param_target";
              }
              {
                source_labels = ["__param_target"];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:9115";
              }
            ];
          }
          {
            job_name = "tasmota";
            metrics_path = "/probe";
            scrape_interval = "10s";
            static_configs = [
              {
                targets = [
                  "living-room-corner.ldn"
                  "living-room-shelf.ldn"
                  "living-room-drawer.ldn"
                  "living-room-sofa.ldn"
                  "office-light.ldn"
                  "office-air.ldn"
                  "living-room-tv.ldn"
                  "office-fridge.ldn"
                  "office-workstation.ldn"
                  "office-fan-heater.ldn"
                  "staircase-servers.ldn"
                ];
              }
            ];
            relabel_configs = [
              {
                source_labels = ["__address__"];
                target_label = "__param_target";
              }
              {
                source_labels = ["__param_target"];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:63459";
              }
            ];
          }
          {
            job_name = "homewizard";
            metrics_path = "/probe";
            scrape_interval = "10s";
            static_configs = [
              {
                targets = [
                  "power-p1-meter.ldn"
                ];
              }
            ];
            relabel_configs = [
              {
                source_labels = ["__address__"];
                target_label = "__param_target";
              }
              {
                source_labels = ["__param_target"];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:63460";
              }
            ];
          }
          {
            job_name = "living-room-window-plant";
            metrics_path = "/";
            scrape_interval = "10s";
            scrape_timeout = "3s";
            static_configs = [
              {
                targets = [
                  "living-room-window-moisture.ldn"
                ];
                labels = {
                  plant = "living-room-window";
                };
              }
            ];
          }
          (scrapeJob "litestream" [
            "core-oracldn:54909"
            # "headscale-oracldn:54909"
          ])
          (scrapeJob "headscale" [
            "core-oracldn:54910"
          ])
        ];

        rules = [
          (
            builtins.toJSON {
              groups = [
                {
                  name = "rules";
                  rules = [
                    {
                      alert = "ExporterDown";
                      expr = ''up{} == 0'';
                      for = "1m";
                      labels = {
                        severity = "critical";
                        frequency = "2m";
                      };
                      annotations = {
                        summary = "Exporter down (instance {{ $labels.instance }})";
                        description = ''
                          Prometheus exporter down

                          VALUE = {{ $value }}
                          LABELS: {{ $labels }}
                        '';
                      };
                    }
                    {
                      alert = "NodeExporterDown";
                      expr = ''up{job="nodes"} == 0'';
                      for = "1m";
                      labels = {
                        severity = "critical";
                        frequency = "2m";
                      };
                      annotations = {
                        summary = "Exporter down (instance {{ $labels.instance }})";
                        description = ''
                          Prometheus exporter down

                          VALUE = {{ $value }}
                          LABELS: {{ $labels }}
                        '';
                      };
                    }
                    {
                      alert = "InstanceLowDiskAbs";
                      expr = ''node_filesystem_avail_bytes{fstype!~"(tmpfs|ramfs)",mountpoint!~"^/boot.?/?.*"} / 1024 / 1024 < 1024'';
                      for = "1m";
                      labels = {
                        severity = "critical";
                      };
                      annotations = {
                        description = "Less than 1GB of free disk space left on the root filesystem";
                        summary = "Instance {{ $labels.instance }}: {{ $value }}MB free disk space on {{$labels.device }} @ {{$labels.mountpoint}}";
                        value = "{{ $value }}";
                      };
                    }
                    (
                      let
                        low_megabyte = 70;
                      in {
                        alert = "InstanceLowBootDiskAbs";
                        expr = ''node_filesystem_avail_bytes{mountpoint=~"^/boot.?/?.*"} / 1024 / 1024 < ${toString low_megabyte}''; # a single kernel roughly consumes about ~40ish MB.
                        for = "1m";
                        labels = {
                          severity = "critical";
                        };
                        annotations = {
                          description = "Less than ${toString low_megabyte}MB of free disk space left on one of the boot filesystem";
                          summary = "Instance {{ $labels.instance }}: {{ $value }}MB free disk space on {{$labels.device }} @ {{$labels.mountpoint}}";
                          value = "{{ $value }}";
                        };
                      }
                    )
                    {
                      alert = "InstanceLowDiskPerc";
                      expr = "100 * (node_filesystem_free_bytes / node_filesystem_size_bytes) < 10";
                      for = "1m";
                      labels = {
                        severity = "critical";
                      };
                      annotations = {
                        description = "Less than 10% of free disk space left on a device";
                        summary = "Instance {{ $labels.instance }}: {{ $value }}% free disk space on {{ $labels.device}}";
                        value = "{{ $value }}";
                      };
                    }
                    {
                      alert = "InstanceLowDiskPrediction12Hours";
                      expr = ''predict_linear(node_filesystem_free_bytes{fstype!~"(tmpfs|ramfs)"}[3h],12 * 3600) < 0'';
                      for = "2h";
                      labels.severity = "critical";
                      annotations = {
                        description = ''Disk {{ $labels.mountpoint }} ({{ $labels.device }}) will be full in less than 12 hours'';
                        summary = ''Instance {{ $labels.instance }}: Disk {{ $labels.mountpoint }} ({{ $labels.device}}) will be full in less than 12 hours'';
                      };
                    }

                    {
                      alert = "InstanceLowMem";
                      expr = "node_memory_MemAvailable_bytes / 1024 / 1024 < node_memory_MemTotal_bytes / 1024 / 1024 / 10";
                      for = "3m";
                      labels.severity = "critical";
                      annotations = {
                        description = "Less than 10% of free memory";
                        summary = "Instance {{ $labels.instance }}: {{ $value }}MB of free memory";
                        value = "{{ $value }}";
                      };
                    }

                    {
                      alert = "ServiceFailed";
                      expr = ''node_systemd_unit_state{state="failed"} > 0'';
                      for = "2m";
                      labels.severity = "critical";
                      annotations = {
                        description = "A systemd unit went into failed state";
                        summary = "Instance {{ $labels.instance }}: Service {{ $labels.name }} failed";
                        value = "{{ $labels.name }}";
                      };
                    }
                    {
                      alert = "ServiceFlapping";
                      expr = ''                        changes(node_systemd_unit_state{state="failed"}[5m])
                                        > 5 or (changes(node_systemd_unit_state{state="failed"}[1h]) > 15
                                        unless changes(node_systemd_unit_state{state="failed"}[30m]) < 7)
                      '';
                      labels.severity = "critical";
                      annotations = {
                        description = "A systemd service changed its state more than 5x/5min or 15x/1h";
                        summary = "Instance {{ $labels.instance }}: Service {{ $labels.name }} is flapping";
                        value = "{{ $labels.name }}";
                      };
                    }
                    {
                      alert = "SystemdUnitActivatingTooLong";
                      expr = ''node_systemd_unit_state{state="activating"} == 1'';
                      for = "5m";
                      labels = {
                        severity = "warning";
                        frequency = "15m";
                      };
                      annotations = {
                        summary = "systemd unit is activating too long (instance {{ $labels.instance }})";
                        description = ''
                          systemd unit is activating for more than 5 minutes

                          LABELS: {{ $labels }}
                        '';
                      };
                    }
                    {
                      alert = "TjodaPingDown";
                      expr = ''probe_success{job="tjoda-ping"} == 0'';
                      for = "10m";
                      labels = {
                        severity = "warning";
                        frequency = "15m";
                      };
                      annotations = {
                        summary = "Tjodalyng device has not responded for 10m (instance {{ $labels.instance }})";
                        description = ''
                          A device in Tjodalyng, typically Unifi networking or Sonos has not responded
                          for over 10m.

                          LABELS: {{ $labels }}
                        '';
                      };
                    }
                  ];
                }
              ];
            }
          )
        ];

        exporters.blackbox = {
          enable = true;
          listenAddress = "127.0.0.1";
          configFile = blackboxConfigFile;
        };

        alertmanager = {
          enable = true;

          listenAddress = "0.0.0.0";

          webExternalUrl = "http://core-oracldn:9093";

          # environmentFile interpolation is done after the check config
          # is done, which means it will fail with a missing discord webhook.
          checkConfig = false;
          environmentFile = config.age.secrets.alertmanager-env.path;

          configuration = {
            route = {
              group_by = ["alertname" "job"];
              receiver = "discord";
            };
            receivers = [
              {
                name = "discord";
                discord_configs = [
                  {
                    webhook_url = "$DISCORD_WEBHOOK_URL";
                  }
                ];
              }
            ];
          };
        };

        pushgateway = {
          enable = true;

          web = {
            external-url = "https://pushgateway.oracldn.fap.no";
            listen-address = "localhost:9091";
          };

          persistMetrics = true;
        };
      };
    }

    (nginx.internalVhost {
      domain = prometheusDomain;
      proxyPass = "http://127.0.0.1:${toString config.services.prometheus.port}";
    })

    (nginx.internalVhost {
      domain = pushgatewayDomain;
      proxyPass = "http://${config.services.prometheus.pushgateway.web.listen-address}";
    })
  ]
