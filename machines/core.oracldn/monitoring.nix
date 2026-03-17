{
  pkgs,
  config,
  lib,
  ...
}: let
  # All NixOS hosts reachable via Tailscale
  # These all have node_exporter and systemd_exporter enabled
  allHosts = [
    "core-oracldn"
    # "core-terra"
    "core-tjoda"
    "dev-oracfurt"
    "dev-ldn"
    "home-ldn"
    "storage-ldn"
  ];

  # Hosts with ZFS pools (have zfs_exporter enabled)
  zfsHosts = [
    # "core-terra"
    "core-tjoda"
    "storage-ldn"
  ];

  # Hosts with smartctl monitoring enabled
  smartctlHosts = [
    "core-tjoda"
  ];

  # Hosts with smokeping exporter
  smokepingHosts = [
    # "core-terra"
    "core-tjoda"
  ];

  # Hosts running CoreDNS (prometheus on :9153)
  corednsHosts = [
    "core-oracldn"
    "core-tjoda"
    "storage-ldn"
  ];

  # Hosts running Nginx with nginxlog exporter (port 9117)
  nginxlogHosts = [
    "core-oracldn"
    # "core-terra"
  ];

  # Restic REST server Tailscale service names
  resticHosts = [
    "restic-tjoda"
    "restic-ldn"
    # "restic-terra"
  ];

  blackboxConfigFile = pkgs.writeText "blackbox.conf" ''
    modules:
      http_prometheus:
        prober: http
        timeout: 5s
        http:
          method: GET
          valid_http_versions: ["HTTP/1.1", "HTTP/2"]
          fail_if_ssl: false
          fail_if_not_ssl: true
          tls_config:
            insecure_skip_verify: false
      icmp:
        prober: icmp
        timeout: 10s
        icmp:
          preferred_ip_protocol: ip4
  '';

  # Helper to create a simple scrape job with /metrics path
  scrapeJob = name: targets: {
    job_name = name;
    metrics_path = "/metrics";
    static_configs = [{inherit targets;}];
  };

  # Helper to create scrape jobs for exporters across multiple hosts
  # Takes a job name, list of hostnames, and port number
  exporterJob = name: hosts: port: {
    job_name = name;
    metrics_path = "/metrics";
    static_configs = [
      {
        targets = map (host: "${host}:${toString port}") hosts;
      }
    ];
  };
in {
  services.tailscale.services = {
    prom = {
      endpoints = {
        "tcp:80" = "http://localhost:${toString config.services.prometheus.port}";
        "tcp:443" = "http://localhost:${toString config.services.prometheus.port}";
      };
    };
    alertmanager = {
      endpoints = {
        "tcp:80" = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
        "tcp:443" = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
      };
    };
    pushgateway = {
      endpoints = {
        "tcp:80" = "http://${config.services.prometheus.pushgateway.web.listen-address}";
        "tcp:443" = "http://${config.services.prometheus.pushgateway.web.listen-address}";
      };
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

    globalConfig = {
      external_labels = {
        cluster = "homelab";
        site = "oracldn";
      };
    };

    alertmanagers = [
      {
        scheme = "http";
        path_prefix = "/";
        static_configs = [
          {targets = ["localhost:${toString config.services.prometheus.alertmanager.port}"];}
        ];
      }
    ];

    scrapeConfigs = [
      # Node exporter on all hosts (port 9100)
      (exporterJob "nodes" allHosts 9100)

      # Systemd exporter on all hosts (port 9558)
      (exporterJob "systemd" allHosts 9558)

      # ZFS exporter on hosts with ZFS pools (port 9134)
      (exporterJob "zfs" zfsHosts 9134)

      # Smartctl exporter on hosts with disk monitoring (port 9633)
      (exporterJob "smartctl" smartctlHosts 9633)

      # Smokeping exporter (port 9374)
      (exporterJob "smokeping" smokepingHosts 9374)

      # CoreDNS metrics (port 9153)
      (exporterJob "coredns" corednsHosts 9153)

      # Nginx log exporter (port 9117)
      (exporterJob "nginxlog" nginxlogHosts 9117)

      # MQTT exporter on home-ldn (port 9000)
      (scrapeJob "mqtt" ["home-ldn:9000"])

      # Restic REST server metrics (via Tailscale service names)
      {
        job_name = "restic-server";
        metrics_path = "/metrics";
        static_configs = [
          {targets = map (h: "${h}:80") resticHosts;}
        ];
      }

      # Incus host metrics
      # The Incus host needs the following configuration:
      #   incus config set core.metrics_authentication false
      # TODO: Ensure Tailscale ACLs allow core-oracldn to reach core-ldn:8443
      {
        job_name = "incus";
        metrics_path = "/1.0/metrics";
        scheme = "https";
        tls_config = {
          insecure_skip_verify = true;
        };
        static_configs = [
          {
            targets = ["core-ldn:8443"];
          }
        ];
      }

      # Application-specific exporters
      (scrapeJob "litestream" ["core-oracldn:54909"])
      (scrapeJob "headscale" ["core-oracldn:54910"])

      # PostgreSQL exporter (port 9187)
      (scrapeJob "postgres" ["core-oracldn:9187"])

      # Blackbox HTTPS probing for public endpoints
      {
        job_name = "https-probes";
        metrics_path = "/probe";
        params = {
          module = ["http_prometheus"];
        };
        static_configs = [
          {
            targets = [
              "https://headscale.kradalby.no"
              "https://uptime.kradalby.no"
              "https://kradalby.no"
              "https://umami.kradalby.no"
              "https://hvor.kradalby.no"
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

      # Blackbox ICMP probing for Tjoda devices
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

      # Tasmota smart plugs
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

      # HomeWizard P1 smart meter
      {
        job_name = "homewizard";
        metrics_path = "/probe";
        scrape_interval = "10s";
        static_configs = [
          {
            targets = ["power-p1-meter.ldn"];
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
    ];

    rules = [
      (builtins.toJSON {
        groups = [
          # Node/host-level alerts
          {
            name = "node";
            rules = [
              {
                alert = "ExporterDown";
                expr = ''up{job!="nodes"} == 0'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "Exporter {{ $labels.job }} down on {{ $labels.instance }}";
                  description = "The {{ $labels.job }} exporter on {{ $labels.instance }} has been unreachable for more than 5 minutes.";
                };
              }
              {
                alert = "NodeExporterDown";
                expr = ''up{job="nodes"} == 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Host {{ $labels.instance }} is unreachable";
                  description = "Node exporter on {{ $labels.instance }} has been down for more than 5 minutes. Is the host powered on? Is Tailscale running?";
                };
              }
              {
                alert = "InstanceLowDiskAbs";
                expr = ''node_filesystem_avail_bytes{fstype!~"(tmpfs|ramfs)",mountpoint!~"^/boot.?/?.*",mountpoint!~"^/var/lib/incus/.*"} / 1024 / 1024 < 1024'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $value }}MB free on {{ $labels.device }} @ {{ $labels.mountpoint }}";
                  description = "Less than 1GB of free disk space left on {{ $labels.mountpoint }}.";
                };
              }
              (
                let
                  low_megabyte = 70;
                in {
                  alert = "InstanceLowBootDiskAbs";
                  expr = ''node_filesystem_avail_bytes{mountpoint=~"^/boot.?/?.*"} / 1024 / 1024 < ${toString low_megabyte}'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.instance }}: {{ $value }}MB free on {{ $labels.device }} @ {{ $labels.mountpoint }}";
                    description = "Less than ${toString low_megabyte}MB of free disk space left on a boot filesystem. A single kernel consumes ~40MB.";
                  };
                }
              )
              {
                alert = "InstanceLowDiskPerc";
                expr = ''100 * (node_filesystem_avail_bytes{fstype!~"(tmpfs|ramfs)",mountpoint!~"^/boot.?/?.*",mountpoint!~"^/var/lib/incus/.*"} / node_filesystem_size_bytes{fstype!~"(tmpfs|ramfs)",mountpoint!~"^/boot.?/?.*",mountpoint!~"^/var/lib/incus/.*"}) < 10'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $value }}% free on {{ $labels.device }}";
                  description = "Less than 10% of free disk space left on {{ $labels.mountpoint }}.";
                };
              }
              {
                alert = "InstanceLowDiskPrediction12Hours";
                expr = ''predict_linear(node_filesystem_free_bytes{fstype!~"(tmpfs|ramfs)",mountpoint!~"^/boot.?/?.*",mountpoint!~"^/var/lib/incus/.*"}[3h],12 * 3600) < 0'';
                for = "2h";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} ({{ $labels.device }}) will be full in <12h";
                  description = "Disk {{ $labels.mountpoint }} ({{ $labels.device }}) on {{ $labels.instance }} is predicted to fill within 12 hours based on the last 3 hours of data.";
                };
              }
              {
                alert = "InstanceLowMem";
                expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 < 10";
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.instance }}: {{ $value }}% memory available";
                  description = "Less than 10% of memory available for more than 30 minutes.";
                };
              }
              {
                alert = "HighCPULoad";
                expr = ''node_load15 > count without (cpu, mode) (node_cpu_seconds_total{mode="idle"})'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: 15m load average {{ $value }} exceeds CPU count";
                  description = "The 15-minute load average on {{ $labels.instance }} has exceeded the number of CPUs for more than 15 minutes.";
                };
              }
              {
                alert = "OOMKill";
                expr = "increase(node_vmstat_oom_kill[1h]) > 0";
                for = "1m";
                labels.severity = "critical";
                annotations = {
                  summary = "OOM kill detected on {{ $labels.instance }}";
                  description = "A process was killed by the OOM killer on {{ $labels.instance }} in the last hour.";
                };
              }
            ];
          }

          # Systemd service alerts
          {
            name = "systemd";
            rules = [
              {
                alert = "ServiceFailed";
                expr = ''systemd_unit_state{state="failed"} > 0'';
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.instance }}: service {{ $labels.name }} failed";
                  description = "The systemd unit {{ $labels.name }} on {{ $labels.instance }} has been in failed state for more than 2 minutes.";
                };
              }
              {
                alert = "ServiceFlapping";
                expr = ''
                  changes(systemd_unit_state{state="failed"}[5m])
                                  > 5 or (changes(systemd_unit_state{state="failed"}[1h]) > 15
                                  unless changes(systemd_unit_state{state="failed"}[30m]) < 7)
                '';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: service {{ $labels.name }} is flapping";
                  description = "The systemd unit {{ $labels.name }} on {{ $labels.instance }} has been changing state rapidly (>5x in 5min or >15x in 1h).";
                };
              }
              {
                alert = "SystemdUnitActivatingTooLong";
                expr = ''systemd_unit_state{state="activating"} == 1'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.instance }}: unit {{ $labels.name }} stuck activating";
                  description = "The systemd unit {{ $labels.name }} on {{ $labels.instance }} has been in activating state for more than 5 minutes.";
                };
              }
            ];
          }

          # ZFS storage alerts
          {
            name = "zfs";
            rules = [
              {
                alert = "ZFSPoolMissing";
                expr = ''up{job="zfs"} == 1 unless on(instance) zfs_pool_health'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS exporter up but no pools found on {{ $labels.instance }}";
                  description = "The ZFS exporter on {{ $labels.instance }} is responding but reports no pool health metrics. This could indicate a disk failure or import issue.";
                };
              }
              {
                alert = "ZFSPoolUnhealthy";
                expr = "zfs_pool_health != 0";
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS pool {{ $labels.pool }} unhealthy on {{ $labels.instance }}";
                  description = "The ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is in a degraded or faulted state.";
                };
              }
              {
                alert = "ZFSPoolSpaceWarning";
                expr = "(zfs_pool_allocated_bytes / zfs_pool_size_bytes) * 100 > 80";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is {{ $value }}% full";
                  description = "ZFS pool {{ $labels.pool }} is above 80% capacity. ZFS performance degrades significantly above this threshold.";
                };
              }
              {
                alert = "ZFSPoolSpaceCritical";
                expr = "(zfs_pool_allocated_bytes / zfs_pool_size_bytes) * 100 > 90";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "ZFS pool {{ $labels.pool }} on {{ $labels.instance }} is {{ $value }}% full";
                  description = "ZFS pool {{ $labels.pool }} is above 90% capacity. Immediate action required.";
                };
              }
            ];
          }

          # SMART disk health alerts
          {
            name = "smartctl";
            rules = [
              {
                alert = "SMARTDiskUnhealthy";
                expr = "smartctl_device_smart_status != 1";
                for = "1m";
                labels.severity = "critical";
                annotations = {
                  summary = "SMART reports disk {{ $labels.device }} unhealthy on {{ $labels.instance }}";
                  description = "SMART self-assessment on {{ $labels.device }} ({{ $labels.model_name }}) indicates the disk is failing.";
                };
              }
              {
                alert = "SMARTDiskTemperature";
                expr = ''smartctl_device_temperature{temperature_type="current"} > 55'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Disk {{ $labels.device }} on {{ $labels.instance }} is {{ $value }}C";
                  description = "Disk temperature on {{ $labels.device }} ({{ $labels.model_name }}) has been above 55C for more than 15 minutes.";
                };
              }
            ];
          }

          # Network and connectivity alerts
          {
            name = "network";
            rules = [
              {
                alert = "TjodaPingDown";
                expr = ''probe_success{job="tjoda-ping"} == 0'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "Tjoda device {{ $labels.instance }} unreachable for 10m";
                  description = "A device in Tjodalyng (typically Unifi networking or Sonos) has not responded for over 10 minutes.";
                };
              }
              {
                alert = "HttpsProbeDown";
                expr = ''probe_success{job="https-probes"} == 0'';
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "HTTPS probe failed for {{ $labels.instance }}";
                  description = "The public HTTPS endpoint {{ $labels.instance }} has been unreachable or returning errors for more than 5 minutes.";
                };
              }
              {
                alert = "TlsCertExpiringSoon";
                expr = ''probe_ssl_earliest_cert_expiry{job="https-probes"} - time() < 14 * 86400'';
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "TLS cert for {{ $labels.instance }} expires in less than 14 days";
                  description = "The TLS certificate for {{ $labels.instance }} will expire soon. Check ACME renewal.";
                };
              }
              {
                alert = "TlsCertExpiryCritical";
                expr = ''probe_ssl_earliest_cert_expiry{job="https-probes"} - time() < 3 * 86400'';
                for = "10m";
                labels.severity = "critical";
                annotations = {
                  summary = "TLS cert for {{ $labels.instance }} expires in less than 3 days";
                  description = "The TLS certificate for {{ $labels.instance }} is about to expire. ACME renewal may be broken.";
                };
              }
              {
                alert = "NetworkInterfaceErrors";
                expr = "rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m]) > 0";
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Network errors on {{ $labels.device }} ({{ $labels.instance }})";
                  description = "Network interface {{ $labels.device }} on {{ $labels.instance }} has been experiencing errors for more than 15 minutes.";
                };
              }
              {
                alert = "SmokepingPacketLoss";
                expr = ''
                  (1 - rate(smokeping_response_duration_seconds_count[5m])
                  / rate(smokeping_requests_total[5m])) > 0.1
                '';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "Packet loss >10% to {{ $labels.host }} from {{ $labels.instance }}";
                  description = "Smokeping is detecting sustained packet loss to {{ $labels.host }}.";
                };
              }
              {
                alert = "SmokepingTargetDown";
                expr = "rate(smokeping_response_duration_seconds_count[5m]) == 0 and rate(smokeping_requests_total[5m]) > 0";
                for = "15m";
                labels.severity = "critical";
                annotations = {
                  summary = "100% packet loss to {{ $labels.host }} from {{ $labels.instance }}";
                  description = "Smokeping is detecting complete packet loss to {{ $labels.host }} for more than 15 minutes.";
                };
              }
            ];
          }

          # Application-level alerts
          {
            name = "application";
            rules = [
              {
                alert = "LitestreamReplicationLag";
                # Litestream exposes replica lag; if it doesn't match this metric name
                # exactly, the rule is harmless (matches no series).
                expr = "litestream_replica_lag_seconds > 300";
                for = "5m";
                labels.severity = "critical";
                annotations = {
                  summary = "Litestream replication lagging for {{ $labels.db }} to {{ $labels.name }}";
                  description = "Litestream replication for database {{ $labels.db }} to replica {{ $labels.name }} has been lagging more than 5 minutes.";
                };
              }
              {
                alert = "PostgreSQLDown";
                expr = "pg_up == 0";
                for = "2m";
                labels.severity = "critical";
                annotations = {
                  summary = "PostgreSQL is down on {{ $labels.instance }}";
                  description = "The PostgreSQL database on {{ $labels.instance }} is unreachable.";
                };
              }
              {
                alert = "PostgreSQLHighConnections";
                expr = "pg_stat_activity_count > 80";
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "PostgreSQL connections high on {{ $labels.instance }}: {{ $value }}";
                  description = "PostgreSQL on {{ $labels.instance }} has more than 80 active connections (default max is 100).";
                };
              }
              {
                alert = "ResticBackupStale";
                expr = ''time() - systemd_timer_last_trigger_seconds{name=~"restic-backups-.*\\.timer"} > 2 * 3600'';
                for = "30m";
                labels.severity = "critical";
                annotations = {
                  summary = "Restic backup {{ $labels.name }} stale on {{ $labels.instance }}";
                  description = "The restic backup timer {{ $labels.name }} on {{ $labels.instance }} has not triggered in over 2 hours (expected: hourly).";
                };
              }
            ];
          }
        ];
      })
    ];

    exporters.blackbox = {
      enable = true;
      listenAddress = "127.0.0.1";
      configFile = blackboxConfigFile;
    };

    alertmanager = {
      enable = true;

      listenAddress = "0.0.0.0";

      webExternalUrl = "http://alertmanager/";

      # environmentFile interpolation is done after the check config
      # is done, which means it will fail with a missing discord webhook.
      checkConfig = false;
      environmentFile = config.age.secrets.alertmanager-env.path;

      configuration = {
        route = {
          group_by = [
            "alertname"
            "instance"
          ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
          receiver = "discord";
          routes = [
            {
              match = {severity = "critical";};
              receiver = "discord";
              group_wait = "10s";
              group_interval = "1m";
              repeat_interval = "1h";
            }
            {
              match = {severity = "warning";};
              receiver = "discord";
              group_wait = "2m";
              group_interval = "10m";
              repeat_interval = "12h";
            }
          ];
        };

        inhibit_rules = [
          {
            # If a node is down, suppress all other alerts from that instance
            source_matchers = ["alertname=\"NodeExporterDown\""];
            target_matchers = ["alertname!=\"NodeExporterDown\""];
            equal = ["instance"];
          }
          {
            # If an exporter is down, suppress downstream alerts from that instance
            source_matchers = ["alertname=\"ExporterDown\""];
            target_matchers = ["alertname!~\"ExporterDown|NodeExporterDown\""];
            equal = ["instance"];
          }
          {
            # Critical inhibits warning for the same alert+instance
            source_matchers = ["severity=\"critical\""];
            target_matchers = ["severity=\"warning\""];
            equal = ["alertname" "instance"];
          }
        ];

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
