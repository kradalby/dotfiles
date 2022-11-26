{
  pkgs,
  config,
  lib,
  ...
}: let
  nginx = import ../../common/funcs/nginx.nix {inherit config lib;};

  prometheusDomain = "prometheus.${config.networking.domain}";
  pushgatewayDomain = "pushgateway.${config.networking.domain}";
in
  lib.mkMerge [
    {
      services.prometheus = {
        enable = true;

        retentionTime = "365d";

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
              {server = "consul.ntnu.fap.no";}
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
        ];

        rules = [
          (
            builtins.toJSON {
              groups = [
                {
                  name = "rules";
                  rules = [
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
                  ];
                }
              ];
            }
          )
        ];

        alertmanager = {
          enable = true;

          listenAddress = "localhost";

          webExternalUrl = "https://alertmanager.oracldn.fap.no";

          configuration = {
            global = {
              smtp_smarthost = "localhost:25";
              smtp_from = "alertmanager@${config.networking.domain}";
            };
            route = {
              receiver = "email";
              routes = [
                {
                  # in the future, when nixpkgs gets more up to date, we should use
                  # matchers. currently amtool throws its hand in the air.
                  match = {severity = "critical";};
                  receiver = "pager";
                }
              ];
            };
            receivers = [
              {
                name = "email";
                email_configs = [
                  {to = "kristoffer@dalby.cc";}
                ];
              }
              # this should eventually be handled by sachet whenever nixpkgs has
              # it upstream
              {
                name = "pager";
                email_configs = [
                  {to = "kristoffer@dalby.cc";}
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
